# frozen_string_literal: true

class AddCreatePagesToImports < ActiveRecord::Migration[5.1]
  def change
    add_column :imports, :create_pages, :boolean, null: false, default: true
  end
end
