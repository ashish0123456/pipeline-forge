require "tmpdir"

class ExecutePipelineRun
  class Failed < StandardError; end
  MAX_LOG_BYTES_PER_JOB = Integer(ENV.fetch("CI_EXECUTOR_MAX_LOG_BYTES_PER_JOB", 1_000_000))

  def self.call(run, archive_fetcher: RepositoryArchive, executor_factory: PipelineCommandExecutor)
    new(run, archive_fetcher:, executor_factory:).call
  end

  def initialize(run, archive_fetcher: RepositoryArchive, executor_factory: PipelineCommandExecutor)
    @run = run
    @archive_fetcher = archive_fetcher
    @executor_factory = executor_factory
  end

  def call
    Dir.mktmpdir("ci-platform-run-#{@run.id}-") do |workspace|
      source_path = @archive_fetcher.call(
        repository_url: @run.source_url,
        commit_sha: @run.commit_sha,
        destination: workspace
      )
      executor = @executor_factory.call(source_path: source_path, run_id: @run.id)
      executor.execute { |runner| execute_jobs(runner) }
    end
  end

  private

  def execute_jobs(runner)
    pending = @run.job_runs.includes(:job).to_a.sort_by { |job_run| [ job_run.job.position, job_run.job.id ] }
    successful_job_ids = []

    until pending.empty?
      job_run = pending.find do |candidate|
        candidate.job.depends_on_ids.all? { |job_id| successful_job_ids.include?(job_id) }
      end
      raise Failed, "Job dependencies cannot be satisfied; check for missing dependencies or a dependency cycle" unless job_run

      pending.delete(job_run)
      begin
        execute_job(runner, job_run)
        successful_job_ids << job_run.job_id
      rescue Failed
        pending.each { |remaining| remaining.update!(status: :cancelled, finished_at: Time.current) }
        raise
      end
    end
  end

  def execute_job(runner, job_run)
    max_attempts = job_run.job.max_attempts

    while job_run.attempt < max_attempts
      job_run.update!(status: :running, attempt: job_run.attempt + 1, started_at: Time.current, finished_at: nil)
      append_log(job_run, "Attempt #{job_run.attempt}: started #{job_run.job_name_snapshot}")

      result = runner.run(job_run.command_snapshot)
      append_log(job_run, result.stdout) if result.stdout.present?
      append_log(job_run, result.stderr) if result.stderr.present?
      job_run.update!(exit_code: result.exit_code)

      if result.exit_code.zero?
        job_run.update!(status: :success, finished_at: Time.current)
        append_log(job_run, "Completed #{job_run.job_name_snapshot}")
        return
      end

      failure = "Command exited with status #{result.exit_code}"
      if job_run.attempt >= max_attempts
        job_run.update!(status: :failed, failure_reason: failure, finished_at: Time.current)
        append_log(job_run, failure)
        raise Failed, "#{job_run.job_name_snapshot} failed: #{failure}"
      end

      job_run.update!(status: :pending, failure_reason: failure)
      append_log(job_run, "#{failure}; retrying")
    end
  rescue StandardError => error
    raise if error.is_a?(Failed)

    job_run.update!(status: :failed, failure_reason: error.message.truncate(2_000), finished_at: Time.current)
    append_log(job_run, "Execution error: #{error.message}")
    raise Failed, "#{job_run.job_name_snapshot} could not run: #{error.message}"
  end

  def append_log(job_run, content)
    @logged_bytes ||= Hash.new(0)
    remaining = MAX_LOG_BYTES_PER_JOB - @logged_bytes[job_run.id]
    return unless remaining.positive?

    safe_content = content.to_s.encode("UTF-8", invalid: :replace, undef: :replace, replace: "�")
    truncated = safe_content.bytesize > remaining
    if truncated
      marker = "\n[log output truncated]"
      safe_content = if remaining > marker.bytesize
        safe_content.byteslice(0, remaining - marker.bytesize).to_s.scrub + marker
      else
        marker.byteslice(0, remaining)
      end
    end
    sequence = job_run.execution_logs.maximum(:sequence).to_i + 1
    job_run.execution_logs.create!(sequence: sequence, content: safe_content)
    @logged_bytes[job_run.id] += safe_content.bytesize
  end
end
