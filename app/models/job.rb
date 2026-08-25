class Job < ApplicationRecord
  belongs_to :pipeline
  has_many :job_runs, dependent: :restrict_with_error

  enum :status, { pending: "pending", running: "running", success: "success", failed: "failed" }

  validates :name, presence: true
  validates :max_attempts, numericality: { only_integer: true, in: 1..10 }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  scope :ordered, -> { order(:position, :id) }

  after_commit :expire_project_cache

  private

  def expire_project_cache
    Rails.cache.increment("projects/index/version")
  end
end
