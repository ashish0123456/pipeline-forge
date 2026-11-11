class JobRun < ApplicationRecord
  belongs_to :pipeline_run
  belongs_to :job
  has_many :execution_logs, dependent: :destroy

  after_update_commit :broadcast_status

  enum :status, { pending: "pending", running: "running", success: "success", failed: "failed", cancelled: "cancelled" }

  validates :attempt, numericality: { greater_than_or_equal_to: 0 }
  validates :job_id, uniqueness: { scope: :pipeline_run_id }
  validates :command_snapshot, presence: true, length: { maximum: 2_000 }
  validates :job_name_snapshot, presence: true

  scope :ready, -> { pending }

  private

  def broadcast_status
    PipelineRunsChannel.broadcast_to(pipeline_run, { id: id, status: status, attempt: attempt }.to_json)
  end
end
