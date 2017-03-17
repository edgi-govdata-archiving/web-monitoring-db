class CreateNewDbSchemaWithGenericPageVersionChangeAnnotation < ActiveRecord::Migration[5.0]
  def initialize(*args)
    super(*args)
    db_connection = ActiveRecord::Base.connection
    @uuid_type = db_connection.valid_type?(:uuid) ? :uuid : :string
    @json_type = db_connection.valid_type?(:jsonb) ? :jsonb : :json
  end

  def add_uuid(table, column, options = {})
    if @uuid_type == :string
      options = options.merge({limit: 36})
    end

    if column == :primary_key
      table.primary_key :uuid, @uuid_type, options
    else
      table.send @uuid_type, column, options
    end
  end

  def change
    # Postgres needs this for proper UUID support
    enable_extension 'uuid-ossp'

    create_table :pages, id: false do |t|
      add_uuid t, :primary_key
      t.string :url, null: false
      t.string :title
      t.string :agency
      t.string :site
      t.timestamps

      t.index :url
    end

    create_table :versions, id: false do |t|
      add_uuid t, :primary_key
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      add_uuid t, :page_uuid, null: false
      t.datetime :capture_time, null: false
      t.string :uri
      t.string :version_hash
      t.string :source_type
      t.send @json_type, :source_metadata
      t.timestamps

      t.index :page_uuid
      t.index :version_hash
      t.foreign_key :pages, column: :page_uuid, primary_key: "uuid"
    end

    create_table :changes, id: false do |t|
      add_uuid t, :primary_key
      add_uuid t, :uuid_from, null: false
      add_uuid t, :uuid_to, null: false
      t.float :priority, default: 0.5
      t.send @json_type, :current_annotation
      t.timestamps

      t.index :uuid_to
      t.index [:uuid_to, :uuid_from], unique: true
      t.foreign_key :versions, column: :uuid_from, primary_key: "uuid"
      t.foreign_key :versions, column: :uuid_to, primary_key: "uuid"
    end

    create_table :annotations, id: false do |t|
      add_uuid t, :primary_key
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      add_uuid t, :change_uuid, null: false
      t.belongs_to :author, foreign_key: {to_table: :users}
      t.send @json_type, :annotation, null: false
      t.timestamps

      t.index :change_uuid
    end
  end
end
