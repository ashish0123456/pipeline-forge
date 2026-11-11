require "test_helper"

class JobsControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_url, params: { email: users(:admin).email, password: "password" }
  end

  test "creates a job with its command" do
    pipeline = pipelines(:one)

    assert_difference("Job.count") do
      post project_pipeline_jobs_url(pipeline.project, pipeline), params: {
        job: { name: "Run tests", command: "bundle exec rails test", status: "pending" }
      }
    end

    assert_redirected_to project_pipeline_job_url(pipeline.project, pipeline, Job.last)
    assert_equal "bundle exec rails test", Job.last.command
  end

  test "rejects a job without a command" do
    pipeline = pipelines(:one)

    assert_no_difference("Job.count") do
      post project_pipeline_jobs_url(pipeline.project, pipeline), params: {
        job: { name: "Empty command", command: "", status: "pending" }
      }
    end

    assert_response :unprocessable_entity
  end
end
