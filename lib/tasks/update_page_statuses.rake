desc 'Update the `status` field on all pages. The first parameter optionally sets what pages to update: "recent" (default, pages updated recently enough to change status), "unknown" (only pages with unknown status), "all" (all pages)'
task :update_page_statuses, [:where, :at_time] => [:environment] do |_t, args|
  where_options = ['recent', 'unknown', 'all']
  where = args[:where] || where_options[0]
  abort("First argument must be one of (#{where_options.join ', '})") unless where_options.include? where

  at_time = args[:at_time]
  if at_time.present? && at_time != 'latest_version'
    at_time = Time.parse(args[:at_time])
  end

  ActiveRecord::Migration.say_with_time('Updating status codes on pages...') do
    DataHelpers.with_activerecord_log_level(:error) do
      page_set = Page.all.order(created_at: :asc)
      case where
      when 'recent'
        page_set = page_set.needing_status_update
      when 'unknown'
        page_set = page_set
          .joins(:versions)
          .where('pages.status IS NULL')
          .where('versions.status IS NOT NULL')
      end

      last_update = Time.now
      completed = 0
      total = page_set.size

      DataHelpers.iterate_each(page_set, batch_size: 500) do |page|
        relative_to = if at_time == 'latest_version'
                        page.latest&.capture_time
                      else
                        at_time
                      end

        page.update_status(relative_to:)
        completed += 1
        if Time.now - last_update > 2
          DataHelpers.log_progress(completed, total)
          last_update = Time.now
        end
      end

      DataHelpers.log_progress(completed, total, end_line: true)
      completed
    end
  end
end
