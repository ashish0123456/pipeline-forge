class ProjectPolicy < ApplicationPolicy
  def show?
    member?
  end

  def index?
    member?
  end

  def create?
    admin?
  end

  def new?
    create?
  end

  def edit?
    update?
  end

  def update?
    maintainer?
  end

  def destroy?
    admin? || maintainer?
  end

  def run?
    maintainer?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if user.admin?

      scope.joins(:project_memberships).where(project_memberships: { user_id: user.id })
    end
  end

  private

  def member?
    admin? || ProjectMembership.exists?(project: record, user: user)
  end

  def maintainer?
    admin? || ProjectMembership.exists?(project: record, user: user, role: :maintainer)
  end

  def admin?
    user.admin?
  end
end
