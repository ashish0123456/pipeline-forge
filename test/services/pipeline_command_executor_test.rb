require "test_helper"

class PipelineCommandExecutorTest < ActiveSupport::TestCase
  test "fails closed unless Docker execution is explicitly enabled" do
    previous = ENV.delete("CI_EXECUTOR")
    executor = PipelineCommandExecutor.new(source_path: "/tmp/source", run_id: 1)

    error = assert_raises(RuntimeError) { executor.execute(->(_runner) { flunk "must not run a command" }) }
    assert_match "Container execution is not configured", error.message
  ensure
    ENV["CI_EXECUTOR"] = previous
  end
end
