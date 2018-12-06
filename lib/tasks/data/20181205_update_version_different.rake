namespace :data do
  desc 'Set the `different` field on all versions.'
  task :'20181205_update_version_different', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating `different` on versions, this will take a while...') do
      with_activerecord_log_level(:error) do
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
    iterate_each(ordered_pages) do |page|
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
      bulk_update(page.versions.reorder(capture_time: :asc), [:different]) do |version|
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
        STDOUT.flush
        last_update = Time.now
      end
    end

    # Move to the next line
    puts ''
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

  # Update many records with different values at once. (But it must update the
  # same *attributes* on each record.) This takes an ActiveRecord collection to
  # iterate over and gather the updates, then a list of the attributes that
  # will be updated.
  #
  # The given block must yield an array containing the new value for each of
  # the specified attributes. If it yields nil, the record won't be updated.
  #
  # NOTE: this only works with Postgres.
  def bulk_update(collection, fields)
    model_type = collection.model
    connection = collection.connection

    values = []
    collection.each do |item|
      changes = yield item
      next if changes.nil? || changes.empty?

      changes = changes.collect {|value| connection.quote(value)}
      values << "('#{item.uuid}', #{changes.join(', ')})"
    end

    return 0 if values.empty?

    setters = fields.collect {|field| "#{field} = valueset.#{field}"}.join(', ')

    collection.connection.execute(
      <<-QUERY
        UPDATE
          #{model_type.table_name}
        SET
          #{setters},
          updated_at = #{connection.quote(Time.now)}
        FROM
          (values #{values.join(',')}) as valueset(uuid, #{fields.join(', ')})
        WHERE
          #{model_type.table_name}.uuid = valueset.uuid::uuid
      QUERY
    )
  end
end
