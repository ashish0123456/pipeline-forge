class EnforcePipelineRunCommitShaFormat < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :pipeline_runs,
      "commit_sha = 'legacy' OR commit_sha ~ '^[a-fA-F0-9]{40}$'",
      name: "pipeline_runs_commit_sha_format_valid"
  end
end
