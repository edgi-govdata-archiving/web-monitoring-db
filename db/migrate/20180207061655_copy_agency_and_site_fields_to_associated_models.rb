class CopyAgencyAndSiteFieldsToAssociatedModels < ActiveRecord::Migration[5.1]
  def up
    iterate_batches(Page.order(created_at: :asc)) do |page|
      page.add_maintainer(page.agency) unless page.agency.blank?
      page.add_tag("site:#{page.site}") unless page.site.blank?
    end
  end

  def down
    # We didn't remove site/page fields, so nothing to do here
  end

  # Kind of like find_each, but allows for ordered queries. We need this since
  # a) UUIDs are not really ordered and b) we are still live inserting data.
  def iterate_batches(collection, batch_size: 1000)
    offset = 0
    loop do
      items = collection.limit(batch_size).offset(offset)
      items.each {|item| yield item}
      break if items.count.zero?

      offset += batch_size
    end
  end
end
