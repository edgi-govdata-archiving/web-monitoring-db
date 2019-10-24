namespace :data do
  desc 'Update the `status` field on all pages.'
  task :'20191024_update_page_statuses', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating status codes on pages...') do
      with_activerecord_log_level(:error) do
        last_update = Time.now
        completed = 0
        total = Page.all.count

        iterate_each(Page.all.order(created_at: :asc)) do |page|
          page.update_status
          completed += 1
          if Time.now - last_update > 2
            log_progress(completed, total)
            last_update = Time.now
          end
        end

        log_progress(completed, total, end_line: true)
        completed
      end
    end
  end

  def log_progress(completed, total, end_line: false)
    ending = end_line ? "\n" : "\r"
    STDOUT.write("   #{completed}/#{total} pages updated#{ending}")
  end

  def with_activerecord_log_level(level = :error)
    original_level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = level
    yield
  ensure
    ActiveRecord::Base.logger.level = original_level
  end

  # Kind of like find_each, but allows for ordered queries. We need this since
  # a) UUIDs are not really ordered and b) we are still live inserting data.
  def iterate_each(collection, batch_size: 500)
    offset = 0
    loop do
      items = collection.limit(batch_size).offset(offset)
      items.each {|item| yield item}
      break if items.count.zero?

      offset += batch_size
    end
  end
end
