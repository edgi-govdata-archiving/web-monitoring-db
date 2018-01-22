class CreateSitesAndAgencies < ActiveRecord::Migration[5.1]
  def change
    create_table :sites, id: false do |t|
      t.primary_key :uuid, :uuid
      t.string :name, null: false
      t.integer :versionista_id
      t.index :name, unique: true
      t.index :versionista_id, unique: true
    end

    create_table :pages_sites, id: false do |t|
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      t.uuid :page_uuid, null: false
      t.uuid :site_uuid, null: false
      t.foreign_key :pages, column: :page_uuid, primary_key: 'uuid'
      t.foreign_key :sites, column: :site_uuid, primary_key: 'uuid'
      t.index :page_uuid
      t.index :site_uuid
      t.index [:page_uuid, :site_uuid], unique: true
    end

    create_table :agencies, id: false do |t|
      t.primary_key :uuid, :uuid
      t.string :name, null: false
      t.index :name, unique: true
    end

    create_table :agencies_pages, id: false do |t|
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      t.uuid :agency_uuid, null: false
      t.uuid :page_uuid, null: false
      t.foreign_key :agencies, column: :agency_uuid, primary_key: 'uuid'
      t.foreign_key :pages, column: :page_uuid, primary_key: 'uuid'
      t.index :agency_uuid
      t.index :page_uuid
      t.index [:agency_uuid, :page_uuid], unique: true
    end
  end
end
