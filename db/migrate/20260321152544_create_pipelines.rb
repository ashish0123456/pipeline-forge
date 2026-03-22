class CreatePipelines < ActiveRecord::Migration[8.1]
  def change
    create_table :pipelines do |t|
      t.string :status
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end
  end
end
