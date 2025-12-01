# frozen_string_literal: true

class RemoveMediaTypeParametersFromVersion < ActiveRecord::Migration[6.0]
  def change
    remove_column :versions, :media_type_parameters, :string, null: true
  end
end
