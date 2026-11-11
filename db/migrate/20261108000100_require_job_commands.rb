class RequireJobCommands < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE jobs
      SET command = 'echo "Please configure this legacy job command" && exit 1'
      WHERE command IS NULL OR btrim(command) = ''
    SQL

    change_column_null :jobs, :command, false
    add_check_constraint :jobs, "length(command) <= 2000", name: "jobs_command_length_valid"
  end

  def down
    remove_check_constraint :jobs, name: "jobs_command_length_valid"
    change_column_null :jobs, :command, true
  end
end
