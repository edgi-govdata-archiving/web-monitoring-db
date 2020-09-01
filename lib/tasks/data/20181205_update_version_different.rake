namespace :data do
  desc 'Set the `different` field on all versions.'
  task :'20181205_update_version_different', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating `different` on versions, this will take a while...') do
      DataHelpers.with_activerecord_log_level(:error) do
        update_different_by_page
      end
    end
  end

  def update_different_by_page
    ordered_pages = Page.all.order(uuid: :asc)
    total_pages = ordered_pages.count

    last_update = Time.now - 10
    page_count = 0
    version_count = 0
    DataHelpers.iterate_each(ordered_pages, batch_size: 500) do |page|
      # This is a more strictly correct method for updating the `different`
      # flag, but it is infeasibly slow for production (~4000 versions/minute)
      # page.versions.reorder(capture_time: :asc)[1..-1].each do |version|
      #   version.update_different_attribute
      #   version_count += 1
      # end

      # Use a custom method for setting `different`. This isn't great, but I'm
      # not sure how to best modify Version#update_different_attribute to make
      # it remotely performant for large updates :\
      previous = nil
      DataHelpers.bulk_update(page.versions.reorder(capture_time: :asc), [:different]) do |version|
        is_different = previous.nil? || previous.version_hash != version.version_hash
        previous = version
        if is_different != version.different?
          version_count += 1
          [is_different]
        end
      end

      page_count += 1
      if page_count == total_pages || Time.now - last_update > 2
        print "  Updated #{page_count} of #{total_pages} pages (#{version_count} versions, date: #{page.created_at})\r"
        $stdout.flush
        last_update = Time.now
      end
    end

    # Move to the next line
    puts ''
  end
end
