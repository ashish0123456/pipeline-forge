class PipelineRun < ApplicationRecord
  belongs_to :pipeline
  has_many :job_runs, dependent: :destroy
  has_many :execution_logs, through: :job_runs

  after_update_commit :broadcast_status

  enum :status, { pending: "pending", running: "running", success: "success", failed: "failed", cancelled: "cancelled" }

  validates :idempotency_key, presence: true, uniqueness: { scope: :pipeline_id }

  scope :recent, -> { order(created_at: :desc) }

  def active?
    pending? || running?
  end

  def refresh_status!
    with_lock do
      reload
      return if failed? || cancelled?

      if job_runs.failed.exists?
        update!(status: :failed, finished_at: Time.current)
      elsif job_runs.where.not(status: :success).none?
        update!(status: :success, finished_at: Time.current)
      end
    end
  end

  private

  def broadcast_status
    PipelineRunsChannel.broadcast_to(self, { id: id, status: status, updated_at: updated_at }.to_json)
  end
end
