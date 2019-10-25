desc 'Update the `status` field on all pages. The first parameter optionally sets what pages to update: "recent" (default, pages updated recently enough to change status), "unknown" (only pages with unknown status), "all" (all pages)'
task :update_page_statuses, [:where] => [:environment] do |_t, args|
  where_options = ['recent', 'unknown', 'all']
  where = args[:where] || where_options[0]
  abort("First argument must be one of (#{where_options.join ', '})") unless where_options.include? where

  ActiveRecord::Migration.say_with_time('Updating status codes on pages...') do
    DataHelpers.with_activerecord_log_level(:error) do
      page_set = Page.all.order(created_at: :asc)
      if where == 'recent'
        page_set = page_set.needing_status_update
      elsif where == 'unknown'
        page_set = page_set
          .joins(:versions)
          .where('pages.status IS NULL')
          .where('versions.status IS NOT NULL')
      end

      last_update = Time.now
      completed = 0
      total = page_set.size

      DataHelpers.iterate_each(page_set) do |page|
        page.update_status
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
