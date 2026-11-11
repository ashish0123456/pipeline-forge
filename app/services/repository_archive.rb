require "fileutils"
require "net/http"
require "timeout"
require "uri"
require "zlib"
require "rubygems/package"

class RepositoryArchive
  class Error < StandardError; end
  class TooLarge < Error; end

  MAX_DOWNLOAD_BYTES = Integer(ENV.fetch("CI_ARCHIVE_MAX_BYTES", 50 * 1024 * 1024))
  MAX_EXTRACTED_BYTES = Integer(ENV.fetch("CI_ARCHIVE_MAX_EXTRACTED_BYTES", 200 * 1024 * 1024))
  MAX_ENTRIES = Integer(ENV.fetch("CI_ARCHIVE_MAX_ENTRIES", 20_000))
  CONNECT_TIMEOUT = 5
  READ_TIMEOUT = 15
  REQUEST_TIMEOUT = 60
  MAX_REDIRECTS = 3
  ALLOWED_REDIRECT_HOSTS = %w[codeload.github.com codeload.githubusercontent.com gitlab.com storage.googleapis.com].freeze

  def self.call(repository_url:, commit_sha:, destination:)
    new(repository_url:, commit_sha:, destination:).call
  end

  def initialize(repository_url:, commit_sha:, destination:)
    @repository_url = repository_url.to_s
    @commit_sha = commit_sha.to_s
    @destination = destination
  end

  def call
    raise Error, "Commit must be a full 40-character SHA" unless @commit_sha.match?(/\A[a-f0-9]{40}\z/i)

    provider, owner, repository = parse_repository!
    archive_uri = archive_uri_for(provider, owner, repository)
    archive_path = File.join(@destination, "source.tar.gz")
    download_archive(archive_uri, archive_path)
    extract_archive(archive_path, File.join(@destination, "source"))
    FileUtils.rm_f(archive_path)
    File.join(@destination, "source")
  rescue URI::InvalidURIError
    raise Error, "Repository URL is invalid"
  ensure
    FileUtils.rm_f(archive_path) if defined?(archive_path) && archive_path
  end

  private

  def parse_repository!
    uri = URI.parse(@repository_url)
    unless uri.is_a?(URI::HTTPS) && uri.userinfo.nil? && uri.port == 443 && uri.query.nil? && uri.fragment.nil?
      raise Error, "Only HTTPS GitHub or GitLab repository URLs are supported"
    end

    segments = uri.path.split("/").reject(&:blank?)
    provider = case uri.host&.downcase
    when "github.com", "www.github.com"
      raise Error, "GitHub URL must be /owner/repository" unless segments.length == 2
      :github
    when "gitlab.com", "www.gitlab.com"
      raise Error, "GitLab URL must be /owner/repository" if segments.length < 2
      raise Error, "GitLab subgroups are not supported in this demo" unless segments.length == 2
      :gitlab
    else
      raise Error, "Only public github.com and gitlab.com repositories are supported"
    end

    owner, repository = segments
    raise Error, "Repository URL contains an invalid path" if segments.any? { |segment| %w[. ..].include?(segment) }
    repository = repository.sub(/\.git\z/i, "")
    unless owner.match?(/\A[a-zA-Z0-9_.-]+\z/) && repository.match?(/\A[a-zA-Z0-9_.-]+\z/)
      raise Error, "Repository URL contains unsupported characters"
    end

    [ provider, owner, repository ]
  end

  def archive_uri_for(provider, owner, repository)
    if provider == :github
      URI("https://codeload.github.com/#{owner}/#{repository}/tar.gz/#{@commit_sha}")
    else
      URI("https://gitlab.com/#{owner}/#{repository}/-/archive/#{@commit_sha}/#{repository}-#{@commit_sha}.tar.gz")
    end
  end

  def download_archive(uri, path, redirects = 0)
    raise Error, "Too many redirects while downloading source" if redirects > MAX_REDIRECTS

    response = nil
    Timeout.timeout(REQUEST_TIMEOUT) do
      Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: CONNECT_TIMEOUT, read_timeout: READ_TIMEOUT) do |http|
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = "CIPlatform/1.0"
        http.request(request) do |result|
          response = result
          case result
          when Net::HTTPSuccess
            declared_size = result["content-length"].to_i
            raise TooLarge, "Repository archive exceeds the download limit" if declared_size > MAX_DOWNLOAD_BYTES

            bytes = 0
            File.open(path, "wb") do |file|
              result.read_body do |chunk|
                bytes += chunk.bytesize
                raise TooLarge, "Repository archive exceeds the download limit" if bytes > MAX_DOWNLOAD_BYTES

                file.write(chunk)
              end
            end
          when Net::HTTPRedirection
            location = result["location"]
            raise Error, "Invalid redirect while downloading source" if location.blank?

            redirect_uri = URI.join(uri.to_s, location)
            unless redirect_uri.is_a?(URI::HTTPS) && redirect_uri.userinfo.nil? && ALLOWED_REDIRECT_HOSTS.include?(redirect_uri.host&.downcase) && redirect_uri.port == 443
              raise Error, "Archive redirected to an unsupported host"
            end

            return download_archive(redirect_uri, path, redirects + 1)
          else
            raise Error, "Repository archive download failed (HTTP #{result.code})"
          end
        end
      end
    end
    response
  rescue Net::OpenTimeout, Net::ReadTimeout, Timeout::Error
    raise Error, "Repository archive download timed out"
  rescue SocketError, IOError, SystemCallError => error
    raise Error, "Repository archive download failed: #{error.message}"
  end

  def extract_archive(archive_path, destination)
    FileUtils.mkdir_p(destination)
    extracted_bytes = 0
    entries = 0

    Zlib::GzipReader.open(archive_path) do |gzip|
      Gem::Package::TarReader.new(gzip) do |tar|
        tar.each do |entry|
          next if entry.full_name == "."

          entries += 1
          raise TooLarge, "Repository archive contains too many files" if entries > MAX_ENTRIES

          relative_path = safe_relative_path(entry.full_name)
          next if relative_path.nil?
          target = File.expand_path(relative_path, destination)
          root = File.expand_path(destination) + File::SEPARATOR
          raise Error, "Repository archive contains an unsafe path" unless target.start_with?(root)

          if entry.directory?
            FileUtils.mkdir_p(target)
          elsif entry.file?
            extracted_bytes += entry.header.size
            raise TooLarge, "Extracted repository exceeds the size limit" if extracted_bytes > MAX_EXTRACTED_BYTES

            FileUtils.mkdir_p(File.dirname(target))
            safe_mode = 0o600 | (entry.header.mode & 0o111)
            File.open(target, "wb", safe_mode) do |file|
              IO.copy_stream(entry, file)
            end
          else
            raise Error, "Repository archive contains an unsupported file type"
          end
        end
      end
    end
  rescue Zlib::Error, Gem::Package::TarInvalidError, EOFError => error
    raise Error, "Repository archive is invalid: #{error.message}"
  end

  def safe_relative_path(path)
    raise Error, "Repository archive contains an unsafe path" if path.include?("\\") || path.include?("\0")

    parts = path.split("/").reject { |part| part.empty? || part == "." }
    raise Error, "Repository archive contains an unsafe path" if parts.empty? || parts.include?("..") || path.start_with?("/")

    parts.drop(1).join("/").presence
  end
end
