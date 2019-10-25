class AddUrlKeyToPage < ActiveRecord::Migration[5.1]
  def change
    add_column :pages, :url_key, :string
    add_index :pages, :url_key

    reversible do |direction|
      direction.up do
        say_with_time('Generating url_keys for pages') do
          page_count = 0
          DataHelpers.iterate_each(Page.order(created_at: :asc)) do |page|
            page_count += 1
            page.update_url_key
          end
          say("#{page_count} pages assessed", :subitem)
        end
      end
    end
  end
end
