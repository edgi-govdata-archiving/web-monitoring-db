class CreateMaintainers < ActiveRecord::Migration[5.1]
  def change
    enable_extension :citext
    enable_extension :pgcrypto

    create_table :maintainers, id: false do |t|
      t.primary_key :uuid, :uuid
      t.citext :name, null: false
      t.uuid :parent_uuid
      t.timestamps

      t.index :name, unique: true
    end

    create_table :maintainerships, id: false do |t|
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      t.uuid :maintainer_uuid, null: false
      t.foreign_key :maintainers, column: :maintainer_uuid, primary_key: 'uuid'
      t.uuid :page_uuid, null: false
      t.foreign_key :pages, column: :page_uuid, primary_key: 'uuid'
      t.datetime :created_at, null: false

      t.index :maintainer_uuid
      t.index :page_uuid
      t.index [:maintainer_uuid, :page_uuid], unique: true
    end
  end
end
