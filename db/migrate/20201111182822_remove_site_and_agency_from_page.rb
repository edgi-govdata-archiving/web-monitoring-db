class RemoveSiteAndAgencyFromPage < ActiveRecord::Migration[6.0]
  def change
    remove_column(:pages, :site)
    remove_column(:pages, :agency)
  end
end
