class CreatePipelineRuns < ActiveRecord::Migration[8.1]
  def change
    create_table :pipeline_runs do |t|
      t.references :pipeline, null: false, foreign_key: true
      t.string :status, null: false, default: "pending"
      t.string :idempotency_key, null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.text :failure_reason
      t.timestamps
    end

    add_index :pipeline_runs, [:pipeline_id, :idempotency_key], unique: true
    add_index :pipeline_runs, :pipeline_id, where: "status IN ('pending', 'running')", name: "index_pipeline_runs_on_active_pipeline"
    add_check_constraint :pipeline_runs, "status IN ('pending', 'running', 'success', 'failed', 'cancelled')", name: "pipeline_runs_status_valid"
  end
end
