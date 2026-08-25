class HardenDefinitionsAndAddExecutionMetadata < ActiveRecord::Migration[8.1]
  def change
    execute "UPDATE pipelines SET status = 'pending' WHERE status IS NULL"
    execute "UPDATE jobs SET status = 'pending' WHERE status IS NULL"
    execute <<~SQL
      UPDATE pipelines
      SET status = CASE status
        WHEN '0' THEN 'pending'
        WHEN '1' THEN 'running'
        WHEN '2' THEN 'success'
        WHEN '3' THEN 'failed'
        ELSE status
      END
    SQL
    execute <<~SQL
      UPDATE jobs
      SET status = CASE status
        WHEN '0' THEN 'pending'
        WHEN '1' THEN 'running'
        WHEN '2' THEN 'success'
        WHEN '3' THEN 'failed'
        ELSE status
      END
    SQL

    change_column_default :pipelines, :status, from: nil, to: "pending"
    change_column_default :jobs, :status, from: nil, to: "pending"
    change_column_null :projects, :name, false
    change_column_null :projects, :repository_url, false
    change_column_null :pipelines, :name, false
    change_column_null :pipelines, :status, false
    change_column_null :jobs, :name, false
    change_column_null :jobs, :status, false

    add_column :jobs, :command, :text
    add_column :jobs, :position, :integer, null: false, default: 0
    add_column :jobs, :max_attempts, :integer, null: false, default: 3
    add_column :jobs, :depends_on_ids, :bigint, array: true, null: false, default: []

    add_check_constraint :pipelines, "status IN ('pending', 'running', 'success', 'failed')", name: "pipelines_status_valid"
    add_check_constraint :jobs, "status IN ('pending', 'running', 'success', 'failed')", name: "jobs_status_valid"
    add_check_constraint :jobs, "max_attempts BETWEEN 1 AND 10", name: "jobs_max_attempts_valid"
    add_check_constraint :jobs, "position >= 0", name: "jobs_position_valid"
    add_index :jobs, [:pipeline_id, :position]
    add_index :jobs, :depends_on_ids, using: :gin
  end
end
