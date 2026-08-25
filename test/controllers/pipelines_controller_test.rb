require "test_helper"

class PipelinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post login_url, params: { email: users(:admin).email, password: "password" }
  end

  test "runs a nested pipeline" do
    Sidekiq::Worker.clear_all

    Sidekiq::Testing.fake! do
      post run_project_pipeline_url(projects(:one), pipelines(:one)),
        headers: { "Idempotency-Key" => "controller-run-1" }, as: :json

      assert_response :accepted
      assert_equal "pending", response.parsed_body.fetch("status")
      assert_equal 1, PipelineRun.where(idempotency_key: "controller-run-1").count
      assert_equal 1, OrchestratePipelineJob.jobs.size
    end
  end
end
