# Tools for working with database data. These are mostly used in rake tasks and migrations.
module DataHelpers
  # Log and rewrite a progress indicator like "  x/y completed"
  def self.log_progress(completed, total, description: 'completed', end_line: false)
    ending = end_line ? "\n" : "\r"
    STDOUT.write("   #{completed}/#{total} #{description}#{ending}")
  end

  # Modify ActiveRecord logging for the duration of a block. Usage:
  #
  #   # Only log errors instead of every SQL query
  #   with_activerecord_log_level(:error)
  #     DataModel.where(condition: value).update(something: new_value)
  #   end
  def self.with_activerecord_log_level(level = :error)
    original_level = ActiveRecord::Base.logger.level
    ActiveRecord::Base.logger.level = level
    yield
  ensure
    ActiveRecord::Base.logger.level = original_level
  end

  # Kind of like find_each, but allows for ordered queries. We need this since
  # a) UUIDs are not really ordered and b) we are still live inserting data.
  def self.iterate_each(collection, batch_size: 1000)
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
  def self.bulk_update(collection, fields)
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
