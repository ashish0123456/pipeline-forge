require "test_helper"

class CommandExecutorTest < ActiveSupport::TestCase
  test "fails closed unless the isolated executor is enabled" do
    previous = ENV.delete("CI_EXECUTOR")

    assert_raises(RuntimeError) { CommandExecutor.call("echo unsafe") }
  ensure
    ENV["CI_EXECUTOR"] = previous
  end
end
