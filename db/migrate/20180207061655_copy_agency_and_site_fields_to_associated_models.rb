# frozen_string_literal: true

class CopyAgencyAndSiteFieldsToAssociatedModels < ActiveRecord::Migration[5.1]
  def up
    DataHelpers.iterate_each(Page.order(created_at: :asc)) do |page|
      page.add_maintainer(page.agency) unless page.agency.blank?
      page.add_tag("site:#{page.site}") unless page.site.blank?
    end
  end

  def down
    # We didn't remove site/page fields, so nothing to do here
  end
end
