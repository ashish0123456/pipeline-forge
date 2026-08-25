class CreateUsersAndMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest, null: false
      t.string :role, null: false, default: "member"
      t.timestamps
    end
    add_index :users, "lower(email)", unique: true, name: "index_users_on_lower_email"
    add_check_constraint :users, "role IN ('member', 'admin')", name: "users_role_valid"

    create_table :project_memberships do |t|
      t.references :project, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end
    add_index :project_memberships, [:project_id, :user_id], unique: true
    add_check_constraint :project_memberships, "role IN ('member', 'maintainer')", name: "project_memberships_role_valid"

    create_table :api_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :token_digest, null: false
      t.datetime :last_used_at
      t.datetime :expires_at
      t.timestamps
    end
    add_index :api_tokens, :token_digest, unique: true
  end
end
