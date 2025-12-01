# frozen_string_literal: true

class AddTitleToVersions < ActiveRecord::Migration[5.1]
  def change
    add_column :versions, :title, :string

    reversible do |dir|
      dir.up do
        say_with_time('Copying titles from pages to versions') do
          page_count = 0
          version_count = 0
          Page.includes(:versions).find_each do |page|
            page_count += 1
            version_count += page.versions.update_all(title: page.title)
          end
          say("#{page_count} pages assessed", :subitem)
          say("#{version_count} versions updated", :subitem)
        end
      end
    end
  end
end
