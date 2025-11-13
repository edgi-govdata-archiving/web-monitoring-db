# frozen_string_literal: true

class AddNetworkErrorToVersions < ActiveRecord::Migration[8.0]
  def change
    change_table :versions do |t|
      t.string :network_error
    end
  end
end
