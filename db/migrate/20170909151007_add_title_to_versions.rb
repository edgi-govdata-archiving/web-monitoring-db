class AddTitleToVersions < ActiveRecord::Migration[5.1]
  def change
    add_column :versions, :title, :string
  end
end
