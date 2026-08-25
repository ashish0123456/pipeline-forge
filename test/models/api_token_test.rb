require "test_helper"

class ApiTokenTest < ActiveSupport::TestCase
  test "stores only a digest and authenticates an unexpired token" do
    token = ApiToken.issue!(users(:admin), name: "test")

    assert token.raw_token.present?
    assert_nil ApiToken.find(token.id).raw_token
    assert_equal users(:admin), ApiToken.authenticate(token.raw_token)
  end

  test "rejects expired tokens" do
    token = ApiToken.issue!(users(:admin), name: "expired", expires_at: 1.minute.ago)

    assert_nil ApiToken.authenticate(token.raw_token)
  end
end
