# frozen_string_literal: true

class AddStatusToVersionsAndPages < ActiveRecord::Migration[5.2]
  def change
    add_column :versions, :status, :integer, null: true
    add_column :pages, :status, :integer, null: true
  end
end
