require "test_helper"

class ProjectTest < ActiveSupport::TestCase
  test "should be valid with valid attributes" do
    project = Project.new(name: "Test Project", repository_url: "https://github.com/test/repo")
    assert project.valid?
  end

  test "should be invalid without name" do
    project = Project.new(repository_url: "https://github.com/test/repo")
    assert_not project.valid?
    assert_includes project.errors[:name], "can't be blank"
  end

  test "should be invalid without repository_url" do
    project = Project.new(name: "Test Project")
    assert_not project.valid?
    assert_includes project.errors[:repository_url], "can't be blank"
  end

  test "only accepts supported public GitHub and GitLab URLs" do
    project = Project.new(name: "Unsafe", repository_url: "http://127.0.0.1/admin")

    assert_not project.valid?
    assert project.errors[:repository_url].any?
  end

  test "should have many pipelines" do
    assert_respond_to Project.new, :pipelines
  end

  test "should destroy dependent pipelines when destroyed" do
    project = projects(:one)
    assert_difference "Pipeline.count", -1 do
      project.destroy
    end
  end
end
