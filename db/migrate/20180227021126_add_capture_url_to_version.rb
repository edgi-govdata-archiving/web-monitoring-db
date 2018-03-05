class AddCaptureUrlToVersion < ActiveRecord::Migration[5.1]
  def change
    add_column :versions, :capture_url, :string

    reversible do |direction|
      direction.up do
        say_with_time('Copying URLs from pages to versions') do
          page_count = 0
          version_count = 0
          iterate_batches(Page.order(created_at: :asc)) do |page|
            page_count += 1
            version_count += page.versions.update_all(capture_url: page.url)
          end
          say("#{page_count} pages assessed", :subitem)
          say("#{version_count} versions updated", :subitem)
        end
      end
    end
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
