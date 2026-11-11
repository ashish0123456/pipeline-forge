class AddSourceRevisionToPipelineRuns < ActiveRecord::Migration[8.1]
  def change
    add_column :pipeline_runs, :commit_sha, :string, null: false, default: "legacy"
    add_column :pipeline_runs, :source_url, :text, null: false, default: ""
  end
end
