class ProjectMembership < ApplicationRecord
  belongs_to :project
  belongs_to :user

  enum :role, { member: "member", maintainer: "maintainer" }
  validates :user_id, uniqueness: { scope: :project_id }
end
