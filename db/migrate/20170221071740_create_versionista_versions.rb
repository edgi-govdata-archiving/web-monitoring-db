class CreateVersionistaVersions < ActiveRecord::Migration[5.0]
  def change
    create_table :versionista_versions do |t|
      t.belongs_to :page, foreign_key: { to_table: :versionista_pages }
      t.references :previous
      t.string :diff_with_previous_url
      t.string :diff_with_first_url
      t.integer :diff_length
      t.string :diff_hash
      t.boolean :relevant, default: true
      t.string :versionista_version_id
      t.jsonb :metadata

      t.timestamps

      t.index :diff_hash
      t.index :versionista_version_id
    end
  end
end
