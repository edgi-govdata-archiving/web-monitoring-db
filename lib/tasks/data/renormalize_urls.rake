namespace :data do
  desc 'Re-normalize the `url` field of Pages and PageUrls`.'
  task :renormalize_urls, [] => [:environment] do
    ActiveRecord::Migration.say_with_time('Renormalizing urls...') do
      DataHelpers.with_activerecord_log_level(:error) do
        last_update = Time.now - 1.minute
        expected = Page.all.count
        total = 0
        changed = 0

        Page.find_each(cursor: [:created_at, :uuid]) do |page|
          did_change = false
          url_records = page.urls.order(created_at: :asc, url: :asc).to_a
          url_records.each do |record|
            normalized_url = PageUrl.normalize_value_for(:url, record.url)

            # PageUrls are meant to be immutable, so just delete the current record and try to re-create a new one with
            # the same attributes.
            next unless normalized_url != record.url

            attributes = record.slice(:url, :from_time, :to_time, :notes)
            record.destroy!
            begin
              page.urls.create!(attributes)
            rescue ActiveRecord::RecordNotUnique
              # It already exists, nothing to do!
            end

            did_change = true
          end

          # This could result in multiple pages with the same URL, but that's not explicitly an error and is also not a
          # case we have in production, so don't bother trying to address it.
          page.normalize_attribute(:url)
          did_change ||= page.changed?
          page.save!

          changed += 1 if did_change
          total += 1
          if Time.now - last_update >= 2
            DataHelpers.log_progress(total, expected)
            last_update = Time.now
          end
        end

        DataHelpers.log_progress(total, expected)
        puts "\n   -> #{changed} pages changed"
        total
      end
    end
  end
end
