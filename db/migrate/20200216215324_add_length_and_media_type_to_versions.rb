class AddLengthAndMediaTypeToVersions < ActiveRecord::Migration[6.0]
  def change
    add_column :versions, :length, :integer, null: true
    add_column :versions, :media_type, :string, null: true
    add_column :versions, :media_type_parameters, :string, null: true
  end
end
