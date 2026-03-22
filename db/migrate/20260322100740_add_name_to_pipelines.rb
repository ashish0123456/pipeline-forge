class AddNameToPipelines < ActiveRecord::Migration[8.1]
  def change
    add_column :pipelines, :name, :string
  end
end
