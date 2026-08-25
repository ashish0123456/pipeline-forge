class CreateAuditEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_events do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.jsonb :metadata, null: false, default: {}
      t.string :request_id
      t.inet :ip_address
      t.timestamps
    end
    add_index :audit_events, [:auditable_type, :auditable_id, :created_at], name: "index_audit_events_on_auditable_and_created"
    add_index :audit_events, [:user_id, :created_at]
  end
end
