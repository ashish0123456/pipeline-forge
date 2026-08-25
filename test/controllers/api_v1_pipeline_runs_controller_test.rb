require "test_helper"

class ApiV1PipelineRunsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:admin)
    @token = ApiToken.issue!(@user, name: "api-test")
    @pipeline = pipelines(:one)
  end

  test "requires authentication" do
    get api_v1_project_pipeline_pipeline_runs_url(@pipeline.project, @pipeline), as: :json

    assert_response :unauthorized
  end

  test "lists authorized runs with bounded pagination" do
    @pipeline.pipeline_runs.create!(idempotency_key: "api-run")

    get api_v1_project_pipeline_pipeline_runs_url(@pipeline.project, @pipeline),
      params: { per_page: 1 }, headers: { "Authorization" => "Bearer #{@token.raw_token}" }, as: :json

    assert_response :success
    assert_equal 1, response.parsed_body.fetch("pagination").fetch("per_page")
    assert_equal 1, response.parsed_body.fetch("data").length
  end
end
