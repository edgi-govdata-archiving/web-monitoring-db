class AddUrlKeyToPage < ActiveRecord::Migration[5.1]
  def change
    add_column :pages, :url_key, :string
    add_index :pages, :url_key

    reversible do |direction|
      direction.up do
        say_with_time('Generating url_keys for pages') do
          page_count = 0
          iterate_batches(Page.order(created_at: :asc)) do |page|
            page_count += 1
            page.update_url_key
          end
          say("#{page_count} pages assessed", :subitem)
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
