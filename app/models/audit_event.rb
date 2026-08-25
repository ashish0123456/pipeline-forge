class AuditEvent < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :auditable, polymorphic: true

  validates :action, :auditable_type, :auditable_id, presence: true
end
