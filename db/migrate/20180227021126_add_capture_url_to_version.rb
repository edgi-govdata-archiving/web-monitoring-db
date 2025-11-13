# frozen_string_literal: true

class AddCaptureUrlToVersion < ActiveRecord::Migration[5.1]
  def change
    add_column :versions, :capture_url, :string

    reversible do |direction|
      direction.up do
        say_with_time('Copying URLs from pages to versions') do
          page_count = 0
          version_count = 0
          DataHelpers.iterate_each(Page.order(created_at: :asc)) do |page|
            page_count += 1
            version_count += page.versions.update_all(capture_url: page.url)
          end
          say("#{page_count} pages assessed", :subitem)
          say("#{version_count} versions updated", :subitem)
        end
      end
    end
  end
end
