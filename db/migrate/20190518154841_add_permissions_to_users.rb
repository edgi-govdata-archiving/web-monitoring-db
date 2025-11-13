# frozen_string_literal: true

class AddPermissionsToUsers < ActiveRecord::Migration[5.2]
  def up
    add_column :users, :permissions, :string, array: true, default: []

    execute "UPDATE users SET permissions = ARRAY['view', 'annotate', 'import'];"
    execute "UPDATE users SET permissions = array_append(permissions, 'manage_users') WHERE admin = TRUE;"
  end

  def down
    execute "UPDATE users SET admin = TRUE WHERE 'manage_users' = ANY(permissions);"

    remove_column :users, :permissions
  end
end
