require "test_helper"

class ExecutePipelineRunTest < ActiveSupport::TestCase
  setup do
    @pipeline = pipelines(:one)
    @run = @pipeline.pipeline_runs.create!(
      idempotency_key: "execute-run-#{SecureRandom.hex(4)}",
      commit_sha: "a" * 40,
      source_url: @pipeline.project.repository_url
    )
    @job_run = @run.job_runs.create!(job: @pipeline.jobs.first, command_snapshot: @pipeline.jobs.first.command, job_name_snapshot: @pipeline.jobs.first.name)
    @source_path = "/tmp/fake-source"
  end

  test "fetches source once, runs the job, and persists output" do
    expected_command = @job_run.command_snapshot
    executor, = build_executor do |command|
      raise "unexpected job command" unless expected_command == command
      PipelineCommandExecutor::Result.new("all checks passed", "", 0)
    end

    archive_fetcher = ->(**) { @source_path }
    executor_factory = ->(**) { executor }
    ExecutePipelineRun.call(@run, archive_fetcher:, executor_factory:)

    assert @job_run.reload.success?
    assert_equal [ "Attempt 1: started #{@job_run.job.name}", "all checks passed", "Completed #{@job_run.job.name}" ], @job_run.execution_logs.order(:sequence).pluck(:content)
  end

  test "retries a failed command up to its configured attempt count" do
    @job_run.job.update!(max_attempts: 2)
    executor, = build_executor do |_command|
      PipelineCommandExecutor::Result.new("", "test failed", 1)
    end

    archive_fetcher = ->(**) { @source_path }
    executor_factory = ->(**) { executor }
    assert_raises(ExecutePipelineRun::Failed) do
      ExecutePipelineRun.call(@run, archive_fetcher:, executor_factory:)
    end

    assert @job_run.reload.failed?
    assert_equal 2, @job_run.attempt, @job_run.failure_reason
    assert_match "Command exited with status 1", @job_run.failure_reason
  end

  private

  def build_executor(&run_command)
    runner = Object.new
    runner.define_singleton_method(:run, &run_command)
    executor = Object.new
    executor.define_singleton_method(:execute) { |&block| block.call(runner) }
    [ executor, runner ]
  end
end
