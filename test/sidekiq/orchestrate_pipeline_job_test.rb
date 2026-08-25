require "test_helper"

class OrchestratePipelineJobTest < ActiveSupport::TestCase
  test "schedules jobs whose dependencies succeeded" do
    pipeline = pipelines(:one)
    dependency = pipeline.jobs.create!(name: "Build", position: 1)
    dependent = pipeline.jobs.create!(name: "Test", position: 2, depends_on_ids: [dependency.id])
    run = pipeline.pipeline_runs.create!(idempotency_key: "orchestration-test")
    first_run = run.job_runs.create!(job: dependency)
    run.job_runs.create!(job: dependent)
    first_run.update!(status: :success)

    Sidekiq::Testing.fake! do
      OrchestratePipelineJob.new.perform(run.id)
      assert_equal [dependent.id], ExecuteJob.jobs.map { |job| job["args"].first }.map { |id| JobRun.find(id).job_id }
    end
  end
end
