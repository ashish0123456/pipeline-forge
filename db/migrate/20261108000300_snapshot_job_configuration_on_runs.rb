class SnapshotJobConfigurationOnRuns < ActiveRecord::Migration[8.1]
  def up
    add_column :job_runs, :command_snapshot, :text
    add_column :job_runs, :job_name_snapshot, :string

    execute <<~SQL
      UPDATE job_runs
      SET command_snapshot = jobs.command,
          job_name_snapshot = jobs.name
      FROM jobs
      WHERE jobs.id = job_runs.job_id
    SQL

    change_column_null :job_runs, :command_snapshot, false
    change_column_null :job_runs, :job_name_snapshot, false
    add_check_constraint :job_runs, "length(command_snapshot) <= 2000", name: "job_runs_command_snapshot_length_valid"
  end

  def down
    remove_check_constraint :job_runs, name: "job_runs_command_snapshot_length_valid"
    remove_column :job_runs, :command_snapshot
    remove_column :job_runs, :job_name_snapshot
  end
end
