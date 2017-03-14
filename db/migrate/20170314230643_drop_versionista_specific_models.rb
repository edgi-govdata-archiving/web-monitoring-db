class DropVersionistaSpecificModels < ActiveRecord::Migration[5.0]
  def change
    drop_table :versionista_versions
    drop_table :versionista_pages
  end
end
