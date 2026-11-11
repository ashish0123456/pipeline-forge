class Project < ApplicationRecord
  validates :name, presence: true
  validates :repository_url, presence: true
  validate :repository_url_is_supported

  has_many :pipelines, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :members, through: :project_memberships, source: :user

  after_commit :expire_project_cache

  private

  def expire_project_cache
    Rails.cache.increment("projects/index/version")
  end

  def repository_url_is_supported
    uri = URI.parse(repository_url.to_s)
    segments = uri.path.split("/").reject(&:blank?)
    valid_host = %w[github.com www.github.com gitlab.com www.gitlab.com].include?(uri.host&.downcase)

    unless uri.is_a?(URI::HTTPS) && valid_host && uri.port == 443 && uri.userinfo.nil? && uri.query.nil? && uri.fragment.nil? && segments.size == 2 && segments.none? { |segment| %w[. ..].include?(segment) } && segments.all? { |segment| segment.match?(/\A[a-zA-Z0-9_.-]+\z/) }
      errors.add(:repository_url, "must be a public GitHub or GitLab HTTPS repository URL")
      return
    end

    segments[1].sub!(/\.git\z/i, "")
    errors.add(:repository_url, "must include a repository name") if segments[1].blank?
  rescue URI::InvalidURIError
    errors.add(:repository_url, "is not a valid URL")
  end
end
