namespace :data do
  desc 'Add default PageUrls to all pages.'
  task :'20201116_add_page_urls', [] => [:environment] do
    ActiveRecord::Migration.say_with_time('Adding page.urls records for existing pages...') do
      DataHelpers.with_activerecord_log_level(:error) do
        last_update = Time.now - 1.minute
        expected = Page.all.count
        total = 0

        DataHelpers.iterate_each(Page.all.order(created_at: :asc)) do |page|
          page.urls.find_or_create_by(url: page.url)
          total += 1

          if Time.now - last_update >= 2
            DataHelpers.log_progress(total, expected)
            last_update = Time.now
          end
        end

        DataHelpers.log_progress(total, expected)
        total
      end
    end
  end
end
