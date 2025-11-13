# frozen_string_literal: true

class AddUpdateBehaviorToImport < ActiveRecord::Migration[5.1]
  def change
    add_column(:imports, :update_behavior, :integer, default: 0, null: false)
  end
end
