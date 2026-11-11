require "test_helper"
require "tmpdir"
require "zlib"
require "rubygems/package"

class RepositoryArchiveTest < ActiveSupport::TestCase
  COMMIT_SHA = "a" * 40

  test "builds a GitHub commit archive URL" do
    archive = RepositoryArchive.new(repository_url: "https://github.com/acme/demo.git", commit_sha: COMMIT_SHA, destination: "/tmp")
    uri = archive.send(:archive_uri_for, :github, "acme", "demo")

    assert_equal "https://codeload.github.com/acme/demo/tar.gz/#{COMMIT_SHA}", uri.to_s
  end

  test "builds a GitLab commit archive URL" do
    archive = RepositoryArchive.new(repository_url: "https://gitlab.com/acme/demo", commit_sha: COMMIT_SHA, destination: "/tmp")
    uri = archive.send(:archive_uri_for, :gitlab, "acme", "demo")

    assert_equal "https://gitlab.com/acme/demo/-/archive/#{COMMIT_SHA}/demo-#{COMMIT_SHA}.tar.gz", uri.to_s
  end

  test "rejects non-public or unsupported repository URLs" do
    archive = RepositoryArchive.new(repository_url: "http://127.0.0.1/admin", commit_sha: COMMIT_SHA, destination: "/tmp")

    assert_raises(RepositoryArchive::Error) { archive.send(:parse_repository!) }
  end

  test "rejects a short revision before making a request" do
    archive = RepositoryArchive.new(repository_url: "https://github.com/acme/demo", commit_sha: "main", destination: "/tmp")

    assert_raises(RepositoryArchive::Error) { archive.call }
  end

  test "rejects archive traversal paths" do
    archive = RepositoryArchive.new(repository_url: "https://github.com/acme/demo", commit_sha: COMMIT_SHA, destination: "/tmp")

    assert_raises(RepositoryArchive::Error) { archive.send(:safe_relative_path, "repo-#{COMMIT_SHA}/../../outside") }
  end

  test "extracts only files under the archive root" do
    Dir.mktmpdir do |directory|
      archive_path = File.join(directory, "source.tar.gz")
      destination = File.join(directory, "source")
      root = "demo-#{COMMIT_SHA}"

      Zlib::GzipWriter.open(archive_path) do |gzip|
        Gem::Package::TarWriter.new(gzip) do |tar|
          tar.mkdir(root, 0o755)
          tar.add_file_simple("#{root}/hello.txt", 0o600, 5) { |file| file.write("hello") }
        end
      end

      archive = RepositoryArchive.new(repository_url: "https://github.com/acme/demo", commit_sha: COMMIT_SHA, destination: directory)
      archive.send(:extract_archive, archive_path, destination)

      assert_equal "hello", File.read(File.join(destination, "hello.txt"))
      assert_not File.exist?(File.join(destination, root))
    end
  end
end
