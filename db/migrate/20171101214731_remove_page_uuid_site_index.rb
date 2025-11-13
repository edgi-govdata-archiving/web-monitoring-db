# frozen_string_literal: true

class RemovePageUuidSiteIndex < ActiveRecord::Migration[5.1]
  def change
    add_index :pages, :site
    remove_index :pages, [:uuid, :site]
  end
end
