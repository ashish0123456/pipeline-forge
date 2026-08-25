require "test_helper"

class PipelineTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    pipeline = Pipeline.new(name: "Test Pipeline", project: projects(:one))
    assert pipeline.valid?
  end

  test "should be invalid without name" do
    pipeline = Pipeline.new(project: projects(:one))
    assert_not pipeline.valid?
    assert_includes pipeline.errors[:name], "can't be blank"
  end

  test "should belong to project" do
    assert_respond_to Pipeline.new, :project
  end

  test "should have many jobs" do
    assert_respond_to Pipeline.new, :jobs
  end

  test "should have default pending status" do
    pipeline = Pipeline.new(name: "Test", project: projects(:one))
    assert_equal "pending", pipeline.status
  end

  test "should destroy dependent jobs when destroyed" do
    pipeline = pipelines(:one)
    assert_difference 'Job.count', -1 do
      pipeline.destroy
    end
  end

  test "status enum values" do
    assert_equal "pending", Pipeline.statuses[:pending]
    assert_equal "running", Pipeline.statuses[:running]
    assert_equal "success", Pipeline.statuses[:success]
    assert_equal "failed", Pipeline.statuses[:failed]
  end
end
