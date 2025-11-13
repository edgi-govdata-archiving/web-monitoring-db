# frozen_string_literal: true

class CreateImports < ActiveRecord::Migration[5.0]
  def change
    create_table :imports do |t|
      t.belongs_to :user, foreign_key: true
      t.integer :status, default: 0, null: false
      t.string :file
      t.jsonb :processing_errors
      t.timestamps
    end
  end
end
