class CreateJobRunsAndExecutionLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :job_runs do |t|
      t.references :pipeline_run, null: false, foreign_key: true
      t.references :job, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.integer :attempt, null: false, default: 0
      t.integer :exit_code
      t.text :failure_reason
      t.datetime :started_at
      t.datetime :finished_at
      t.timestamps
    end

    add_index :job_runs, [:pipeline_run_id, :job_id], unique: true
    add_index :job_runs, [:pipeline_run_id, :status]
    add_check_constraint :job_runs, "status IN ('pending', 'running', 'success', 'failed', 'cancelled')", name: "job_runs_status_valid"
    add_check_constraint :job_runs, "attempt >= 0", name: "job_runs_attempt_valid"

    create_table :execution_logs do |t|
      t.references :job_run, null: false, foreign_key: true
      t.integer :sequence, null: false
      t.text :content, null: false
      t.timestamps
    end

    add_index :execution_logs, [:job_run_id, :sequence], unique: true
  end
end
