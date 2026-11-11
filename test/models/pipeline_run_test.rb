require "test_helper"

class PipelineRunTest < ActiveSupport::TestCase
  test "creates one job run per ordered pipeline job" do
    Sidekiq::Worker.clear_all
    pipeline = pipelines(:one)
    pipeline.jobs.create!(name: "Second", command: "echo second", position: 2)
    pipeline.jobs.create!(name: "First", command: "echo first", position: 1)

    Sidekiq::Testing.fake! do
      run = CreatePipelineRun.call(pipeline, idempotency_key: "request-1", commit_sha: "a" * 40)

      assert_equal "pending", run.status
      assert_equal "a" * 40, run.commit_sha
      assert_equal pipeline.project.repository_url, run.source_url
      assert_equal pipeline.jobs.count, run.job_runs.count
      assert_equal pipeline.jobs.ordered.pluck(:command), run.job_runs.includes(:job).sort_by { |job_run| [ job_run.job.position, job_run.job.id ] }.map(&:command_snapshot)
      actual_order = run.job_runs.includes(:job).sort_by { |job_run| [ job_run.job.position, job_run.job.id ] }.map(&:job_id)
      assert_equal pipeline.jobs.ordered.pluck(:id), actual_order
      assert_equal 1, OrchestratePipelineJob.jobs.size
    end
  end

  test "reuses an idempotent request" do
    Sidekiq::Worker.clear_all
    pipeline = pipelines(:one)

    Sidekiq::Testing.fake! do
      first = CreatePipelineRun.call(pipeline, idempotency_key: "request-2", commit_sha: "b" * 40)
      second = CreatePipelineRun.call(pipeline, idempotency_key: "request-2", commit_sha: "b" * 40)

      assert_equal first.id, second.id
      assert_equal 1, pipeline.pipeline_runs.count
    end
  end

  test "requires a full commit SHA" do
    error = assert_raises(ArgumentError) do
      CreatePipelineRun.call(pipelines(:one), idempotency_key: "bad-sha", commit_sha: "main")
    end

    assert_match "full 40-character commit SHA", error.message
  end

  test "keeps the original job command if the definition later changes" do
    pipeline = pipelines(:one)
    original_command = pipeline.jobs.first.command

    run = CreatePipelineRun.call(pipeline, idempotency_key: "snapshot-test", commit_sha: "c" * 40)
    pipeline.jobs.first.update!(command: "echo edited after run")

    assert_equal original_command, run.job_runs.first.command_snapshot
  end
end
