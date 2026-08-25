class ExecuteJob
  include Sidekiq::Job

  sidekiq_options retry: 0, dead: true

  def perform(job_run_id)
    job_run = JobRun.includes(:job, :pipeline_run).find(job_run_id)

    job_run.with_lock do
      next unless job_run.pending? || job_run.failed?

      job_run.update!(status: :running, attempt: job_run.attempt + 1, started_at: Time.current)
      ExecutionLog.create!(job_run: job_run, sequence: 0, content: "Started #{job_run.job.name}")

      result = if job_run.job.command.present?
        CommandExecutor.call(job_run.job.command)
      else
        CommandExecutor::Result.new("", "", 0)
      end
      ExecutionLog.create!(job_run: job_run, sequence: 1, content: result.stdout) if result.stdout.present?
      ExecutionLog.create!(job_run: job_run, sequence: 2, content: result.stderr) if result.stderr.present?
      raise "Command exited with status #{result.exit_code}" unless result.exit_code.zero?

      job_run.update!(status: :success, exit_code: result.exit_code, finished_at: Time.current)
      ExecutionLog.create!(job_run: job_run, sequence: 3, content: "Completed #{job_run.job.name}")
    rescue StandardError => error
      terminal_failure = job_run.attempt >= job_run.job.max_attempts
      job_run.update!(status: terminal_failure ? :failed : :pending,
        failure_reason: error.message, finished_at: terminal_failure ? Time.current : nil)
      raise if terminal_failure
    end

    OrchestratePipelineJob.perform_async(job_run.pipeline_run_id)
  end
end
