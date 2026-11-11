require "test_helper"

class OrchestratePipelineJobTest < ActiveSupport::TestCase
  test "runs a pipeline and records a terminal success status" do
    pipeline = pipelines(:one)
    run = pipeline.pipeline_runs.create!(idempotency_key: "orchestration-test", commit_sha: "a" * 40, source_url: pipeline.project.repository_url)
    job = pipeline.jobs.first
    run.job_runs.create!(job: job, command_snapshot: job.command, job_name_snapshot: job.name)

    worker = Class.new(OrchestratePipelineJob) do
      private

      def execute_pipeline(_run)
        true
      end
    end.new
    worker.perform(run.id)

    assert run.reload.success?
    assert_not_nil run.finished_at
  end
end
