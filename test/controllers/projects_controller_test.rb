require "test_helper"

class ProjectsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get projects_url
    assert_response :success
  end

  test "should get new" do
    get new_project_url
    assert_response :success
  end

  test "should create project" do
    assert_difference('Project.count') do
      post projects_url, params: { project: { name: "New Project", repository_url: "https://github.com/test/new" } }
    end

    assert_redirected_to project_url(Project.last)
  end

  test "should show project" do
    get project_url(projects(:one))
    assert_response :success
  end

  test "should get edit" do
    get edit_project_url(projects(:one))
    assert_response :success
  end

  test "should update project" do
    patch project_url(projects(:one)), params: { project: { name: "Updated Project" } }
    assert_redirected_to project_url(projects(:one))
  end

  test "should destroy project" do
    assert_difference('Project.count', -1) do
      delete project_url(projects(:one))
    end

    assert_redirected_to projects_url
  end
end
