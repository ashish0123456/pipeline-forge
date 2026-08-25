class EnforceOneActivePipelineRun < ActiveRecord::Migration[8.1]
  def change
    remove_index :pipeline_runs, name: "index_pipeline_runs_on_active_pipeline"
    add_index :pipeline_runs, :pipeline_id, unique: true,
      where: "status IN ('pending', 'running')",
      name: "index_pipeline_runs_on_one_active_pipeline"
  end
end
