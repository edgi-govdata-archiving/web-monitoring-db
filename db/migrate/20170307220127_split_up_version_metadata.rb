class SplitUpVersionMetadata < ActiveRecord::Migration[5.0]
  def change
    change_table :versionista_versions do |t|
      t.jsonb :annotations
      t.rename :metadata, :current_annotation
    end
  end
end
