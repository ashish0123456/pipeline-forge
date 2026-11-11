require "test_helper"

class PipelineRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_url, params: { email: users(:admin).email, password: "password" }
  end

  test "shows the pinned source and job command snapshot" do
    pipeline = pipelines(:one)
    job = pipeline.jobs.first
    run = pipeline.pipeline_runs.create!(
      idempotency_key: "view-run-#{SecureRandom.hex(4)}",
      commit_sha: "d" * 40,
      source_url: pipeline.project.repository_url
    )
    run.job_runs.create!(job: job, command_snapshot: job.command, job_name_snapshot: job.name)

    get project_pipeline_pipeline_run_url(pipeline.project, pipeline, run)

    assert_response :success
    assert_includes response.body, "d" * 40
    assert_includes response.body, job.command
  end
end
