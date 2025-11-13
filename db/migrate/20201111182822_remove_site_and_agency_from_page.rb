# frozen_string_literal: true

class RemoveSiteAndAgencyFromPage < ActiveRecord::Migration[6.0]
  def change
    remove_column(:pages, :site, :string)
    remove_column(:pages, :agency, :string)
  end
end
