class Project < ApplicationRecord
  validates :name, presence: true
  validates :repository_url, presence: true, format: { with: URI::regexp(%w[http https]) }

  has_many :pipelines, dependent: :destroy
  has_many :project_memberships, dependent: :destroy
  has_many :members, through: :project_memberships, source: :user

  after_commit :expire_project_cache

  private

  def expire_project_cache
    Rails.cache.increment("projects/index/version")
  end
end
