require "test_helper"

class JobTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    job = Job.new(name: "Test Job", command: "echo test", pipeline: pipelines(:one))
    assert job.valid?
  end

  test "should be invalid without name" do
    job = Job.new(pipeline: pipelines(:one))
    assert_not job.valid?
    assert_includes job.errors[:name], "can't be blank"
  end

  test "should belong to pipeline" do
    assert_respond_to Job.new, :pipeline
  end

  test "should have default pending status" do
    job = Job.new(name: "Test", command: "echo test", pipeline: pipelines(:one))
    assert_equal "pending", job.status
  end

  test "status enum values" do
    assert_equal "pending", Job.statuses[:pending]
    assert_equal "running", Job.statuses[:running]
    assert_equal "success", Job.statuses[:success]
    assert_equal "failed", Job.statuses[:failed]
  end

  test "requires a command within the size limit" do
    job = Job.new(name: "Test", pipeline: pipelines(:one), command: " ")
    assert_not job.valid?
    assert_includes job.errors[:command], "can't be blank"

    job.command = "echo #{'x' * 2_000}"
    assert_not job.valid?
    assert job.errors[:command].any?
  end
end
