namespace :data do
  desc 'Set `domain:` and `2l-domain` tags on all pages.'
  task :'20190112_add_page_domain_tags', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating domain tags on pages...') do
      with_activerecord_log_level(:error) do
        iterate_each(Page.all.order(created_at: :asc), &:ensure_domain_tags)
      end
    end
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
