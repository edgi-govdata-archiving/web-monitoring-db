class CreateNewDbSchemaWithGenericPageVersionChangeAnnotation < ActiveRecord::Migration[5.0]
  def change
    # Postgres needs this for proper UUID support
    enable_extension 'uuid-ossp'

    create_table :pages, id: false do |t|
      table.primary_key :uuid, :uuid
      t.string :url, null: false
      t.string :title
      t.string :agency
      t.string :site
      t.timestamps

      t.index :url
    end

    create_table :versions, id: false do |t|
      table.primary_key :uuid, :uuid
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      table.uuid :page_uuid, null: false
      t.datetime :capture_time, null: false
      t.string :uri
      t.string :version_hash
      t.string :source_type
      t.jsonb :source_metadata
      t.timestamps

      t.index :page_uuid
      t.index :version_hash
      t.foreign_key :pages, column: :page_uuid, primary_key: "uuid"
    end

    create_table :changes, id: false do |t|
      table.primary_key :uuid, :uuid
      t.uuid :uuid_from, null: false
      t.uuid :uuid_to, null: false
      t.float :priority, default: 0.5
      t.jsonb :current_annotation
      t.timestamps

      t.index :uuid_to
      t.index [:uuid_to, :uuid_from], unique: true
      t.foreign_key :versions, column: :uuid_from, primary_key: "uuid"
      t.foreign_key :versions, column: :uuid_to, primary_key: "uuid"
    end

    create_table :annotations, id: false do |t|
      table.primary_key :uuid, :uuid
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      t.uuid :change_uuid, null: false
      t.belongs_to :author, foreign_key: {to_table: :users}
      t.jsonb :annotation, null: false
      t.timestamps

      t.index :change_uuid
    end
  end
end
