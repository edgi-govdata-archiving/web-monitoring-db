class ChangeIntToBigintForPrimaryKeys < ActiveRecord::Migration[7.0]
  def change_serial_primary_key_type(table, key, key_type)
    change_column table, key, key_type
    execute "ALTER SEQUENCE #{table}_#{key}_seq AS #{key_type};"
  end

  def up
    # Foreign Keys
    change_column :annotations, :author_id, :bigint
    change_column :imports, :user_id, :bigint
    change_column :invitations, :issuer_id, :bigint
    change_column :invitations, :redeemer_id, :bigint

    # Primary Keys
    change_serial_primary_key_type :imports, :id, :bigint
    change_serial_primary_key_type :invitations, :id, :bigint
    change_serial_primary_key_type :users, :id, :bigint
  end

  def down
    # Primary Keys
    change_serial_primary_key_type :imports, :id, :int
    change_serial_primary_key_type :invitations, :id, :int
    change_serial_primary_key_type :users, :id, :int

    # Foreign Keys
    change_column :annotations, :author_id, :int
    change_column :imports, :user_id, :int
    change_column :invitations, :issuer_id, :int
    change_column :invitations, :redeemer_id, :int
  end
end
