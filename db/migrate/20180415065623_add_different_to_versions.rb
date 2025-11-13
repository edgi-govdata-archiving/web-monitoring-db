# frozen_string_literal: true

class AddDifferentToVersions < ActiveRecord::Migration[5.1]
  def change
    add_column :versions, :different, :boolean, default: true
  end
end
