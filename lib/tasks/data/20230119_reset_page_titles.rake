# frozen_string_literal: true

namespace :data do
  desc 'Reset the titles for all pages based on new logic.'
  task :'20230119_reset_page_titles', [] => [:environment] do
    ActiveRecord::Migration.say_with_time('Resetting titles for existing pages...') do
      DataHelpers.with_activerecord_log_level(:error) do
        last_update = 1.minute.ago
        expected = Page.all.count
        total = 0

        DataHelpers.iterate_each(Page.all.order(created_at: :asc)) do |page|
          page.update_page_title
          total += 1

          if Time.zone.now - last_update >= 2
            DataHelpers.log_progress(total, expected)
            last_update = Time.zone.now
          end
        end

        DataHelpers.log_progress(total, expected)
        total
      end
    end
  end
end
