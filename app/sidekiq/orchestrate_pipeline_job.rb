class OrchestratePipelineJob
  include Sidekiq::Job

  sidekiq_options retry: 5, dead: true

  def perform(pipeline_run_id)
    run = PipelineRun.includes(:pipeline, job_runs: :job).find(pipeline_run_id)
    run.with_lock do
      return unless run.pending?

      run.update!(status: :running, started_at: run.started_at || Time.current)
    end

    execute_pipeline(run)
    run.update!(status: :success, finished_at: Time.current)
  rescue StandardError => error
    run&.job_runs&.where(status: :running)&.each do |job_run|
      job_run.update(status: :failed, failure_reason: error.message.to_s.truncate(2_000), finished_at: Time.current)
    end
    run&.job_runs&.where(status: :pending)&.each do |job_run|
      job_run.update(status: :cancelled, finished_at: Time.current)
    end
    run&.update(status: :failed, failure_reason: error.message.to_s.truncate(2_000), finished_at: Time.current)
    Rails.logger.error("Pipeline run #{pipeline_run_id} failed: #{error.class}: #{error.message}")
  end

  private

  def execute_pipeline(run)
    ExecutePipelineRun.call(run)
  end
end
