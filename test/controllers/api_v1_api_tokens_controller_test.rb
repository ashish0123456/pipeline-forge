require "test_helper"

class ApiV1ApiTokensControllerTest < ActionDispatch::IntegrationTest
  test "issues a token without persisting its raw value" do
    user = users(:admin)
    post api_v1_api_tokens_url, params: { name: "build bot" }, headers: { "Authorization" => "Bearer #{issue_session_token(user)}" }, as: :json

    assert_response :created
    raw_token = response.parsed_body.fetch("data").fetch("token")
    assert_equal user, ApiToken.authenticate(raw_token)
    assert_nil ApiToken.find_by(name: "build bot").raw_token
  end

  private

  def issue_session_token(user)
    ApiToken.issue!(user, name: "session").raw_token
  end
end
