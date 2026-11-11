class ConstrainPipelineRunCommitSha < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :pipeline_runs, "commit_sha = 'legacy' OR length(commit_sha) = 40", name: "pipeline_runs_commit_sha_length_valid"
  end
end
