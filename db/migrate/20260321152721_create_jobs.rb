class CreateJobs < ActiveRecord::Migration[8.1]
  def change
    create_table :jobs do |t|
      t.string :name
      t.string :status
      t.references :pipeline, null: false, foreign_key: true

      t.timestamps
    end
  end
end
