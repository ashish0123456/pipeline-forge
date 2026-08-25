class OrchestratePipelineJob
  include Sidekiq::Job

  sidekiq_options retry: 5, dead: true

  def perform(pipeline_run_id)
    run = PipelineRun.includes(:pipeline, job_runs: :job).find(pipeline_run_id)

    run.with_lock do
      next if run.success? || run.failed? || run.cancelled?

      run.update!(status: :running, started_at: run.started_at || Time.current)
      schedule_ready_jobs(run)
    end
  end

  private

  def schedule_ready_jobs(run)
    successful_job_ids = run.job_runs.where(status: :success).pluck(:job_id)

    run.job_runs.pending.includes(:job).find_each do |job_run|
      dependencies = job_run.job.depends_on_ids
      next unless dependencies.all? { |dependency_id| successful_job_ids.include?(dependency_id) }

      ExecuteJob.perform_async(job_run.id)
    end

    run.refresh_status!
  end
end
