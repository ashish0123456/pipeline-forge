module Auditable
  extend ActiveSupport::Concern

  private

  def record_audit!(action, record, metadata = {})
    AuditEvent.create!(
      user: current_user,
      action: action,
      auditable: record,
      metadata: metadata,
      request_id: request.request_id,
      ip_address: request.remote_ip
    )
  end
end
