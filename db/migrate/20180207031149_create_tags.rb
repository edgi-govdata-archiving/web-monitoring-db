class CreateTags < ActiveRecord::Migration[5.1]
  def change
    enable_extension :citext

    create_table :tags, id: false do |t|
      t.primary_key :uuid, :uuid
      t.citext :name, null: false
      t.timestamps

      t.index :name, unique: true
    end

    create_table :taggings, id: false do |t|
      # No way to use `belongs_to/references` to make a column named `*_uuid`

      # Polymorphic associations are an ID + a string column
      t.uuid :taggable_uuid, null: false, index: true
      t.string :taggable_type

      t.uuid :tag_uuid, null: false, index: true
      t.foreign_key :tags, column: :tag_uuid, primary_key: 'uuid'

      t.datetime :created_at, null: false

      t.index [:taggable_uuid, :tag_uuid], unique: true
    end
  end
end
