class Pipeline < ApplicationRecord
  belongs_to :project
  has_many :jobs, dependent: :destroy
  has_many :pipeline_runs, dependent: :destroy

  enum :status, { pending: "pending", running: "running", success: "success", failed: "failed" }

  validates :name, presence: true

  scope :with_recent_runs, -> { includes(:project, :pipeline_runs) }

  after_commit :expire_project_cache

  private

  def expire_project_cache
    Rails.cache.increment("projects/index/version")
  end
end
