class AddSkipUnchangedVersionsToImports < ActiveRecord::Migration[5.1]
  def change
    add_column :imports, :skip_unchanged_versions, :boolean, null: false, default: false
  end
end
