require "test_helper"

class PipelineRunTest < ActiveSupport::TestCase
  test "creates one job run per ordered pipeline job" do
    Sidekiq::Worker.clear_all
    pipeline = pipelines(:one)
    pipeline.jobs.create!(name: "Second", position: 2)
    pipeline.jobs.create!(name: "First", position: 1)

    Sidekiq::Testing.fake! do
      run = CreatePipelineRun.call(pipeline, idempotency_key: "request-1")

      assert_equal "pending", run.status
      assert_equal pipeline.jobs.count, run.job_runs.count
      actual_order = run.job_runs.includes(:job).sort_by { |job_run| [job_run.job.position, job_run.job.id] }.map(&:job_id)
      assert_equal pipeline.jobs.ordered.pluck(:id), actual_order
      assert_equal 1, OrchestratePipelineJob.jobs.size
    end
  end

  test "reuses an idempotent request" do
    Sidekiq::Worker.clear_all
    pipeline = pipelines(:one)

    Sidekiq::Testing.fake! do
      first = CreatePipelineRun.call(pipeline, idempotency_key: "request-2")
      second = CreatePipelineRun.call(pipeline, idempotency_key: "request-2")

      assert_equal first.id, second.id
      assert_equal 1, pipeline.pipeline_runs.count
    end
  end
end
