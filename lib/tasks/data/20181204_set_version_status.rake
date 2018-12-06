namespace :data do
  desc 'Set the `status` field on all versions based on `source_metadata`.'
  task :'20181204_set_version_status', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating `status` on versions') do
      with_activerecord_log_level(:error) do
        set_version_statuses
      end
    end
  end

  def set_version_statuses
    query = Version
      .where(source_type: 'versionista')
      .where("versions.source_metadata ? 'error_code'")
      .order(created_at: :desc)

    for_each_batch(query, 1000, 'Updating {n} versionista versions...') do |collection|
      bulk_update(collection, [:status]) do |version|
        [version.source_metadata['error_code'].to_i]
      end
    end

    query = Version
      .where(source_type: 'internet_archive')
      .order(created_at: :desc)

    for_each_batch(query, 1000, 'Updating {n} wayback versions...') do |collection|
      bulk_update(collection, [:status]) do |version|
        [version.source_metadata['status_code'].to_i]
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

  # Blocks an ActiveRecord query into batches of N records, then calls a block
  # with the query for each batch. Optionally accepts a message to log before
  # each batch. "{n}" in the message will be replaced with the number of items
  # in the batch.
  #
  # The given block can yield a new query, which is useful in cases where the
  # block modifies records in a way that would change what would be in the next
  # batch.
  def for_each_batch(query, batch_size, message = nil)
    total = 0
    offset = 0
    loop do
      items = query.limit(batch_size).offset(offset)
      count = items.count
      offset += batch_size
      total += count

      if message
        if count.positive?
          print "  #{message.gsub('{n}', count.to_s)}\r"
        else
          print "\n"
        end
        STDOUT.flush
      end

      break if count.zero?

      next_query = yield items
      if !next_query.nil? && next_query.respond_to?(:limit) && next_query.respond_to?(:offset)
        query = next_query
        offset = 0
      end
    end

    total
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
