require "test_helper"

class JobTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    job = Job.new(name: "Test Job", pipeline: pipelines(:one))
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
    job = Job.new(name: "Test", pipeline: pipelines(:one))
    assert_equal "pending", job.status
  end

  test "status enum values" do
    assert_equal 0, Job.statuses[:pending]
    assert_equal 1, Job.statuses[:running]
    assert_equal 2, Job.statuses[:success]
    assert_equal 3, Job.statuses[:failed]
  end
end
