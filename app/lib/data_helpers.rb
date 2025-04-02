# Tools for working with database data. These are mostly used in rake tasks and migrations.
module DataHelpers
  class ProgressLogger
    attr_accessor :total

    def initialize(expected, interval: 2.seconds)
      expected = DataHelpers.estimate_row_count(expected) if expected.is_a?(Class)
      @expected = expected
      @interval = interval
      @last_update = Time.now - @interval
      @total = 0
    end

    def increment(amount = 1, log: nil)
      @total += amount
      log = Time.now - @last_update >= @interval if log.nil?
      self.log if log
    end

    def log(end_line: false)
      DataHelpers.log_progress(@total, @expected, end_line:)
      @last_update = Time.now
    end

    def complete
      log(end_line: true)
    end
  end

  # Log and rewrite a progress indicator like "  x/y completed"
  def self.log_progress(completed, total, description: 'completed', end_line: false)
    ending = if $stdout.isatty
               end_line ? "\n" : ''
             else
               " (#{Time.now})\n"
             end
    $stdout.write("\r   #{completed}/#{total} #{description}#{ending}")
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
  def self.iterate_each(collection, batch_size: 1000, &)
    offset = 0
    loop do
      items = collection.limit(batch_size).offset(offset)
      items.each(&)
      break if items.count.zero?

      offset += batch_size
    end
  end

  # Extremely large offset values can cause poor query performance, so if
  # iterate_each is used to iterate through an extremely large table, it can
  # get very slow as you proceed through. This breaks up calls to iterate_each
  # into smaller, time-bounded chunks (only useful if you have a time-based
  # column, like :created_at, indexed).
  def self.iterate_time(collection, interval: nil, start_time: nil, end_time: nil, field: :created_at, &)
    interval ||= 15.days
    start_time ||= Time.new(2016, 1, 1)
    batch_size = 500
    total = 0

    while start_time < (end_time || Time.now)
      iterable = collection.order({ field => :asc }).where_in_unbounded_range(
        field,
        [start_time, start_time + interval]
      )
      total = iterate_each(iterable, batch_size:, &)
      start_time += interval
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
  def self.bulk_update(collection, fields)
    model_type = collection.model
    connection = collection.connection

    values = []
    collection.each do |item|
      changes = yield item
      next if changes.nil? || changes.empty?

      changes = changes.collect do |value|
        # TODO: consider using model_type.attribute_types[field_name] to determine to to serialize
        if value.is_a? Hash
          "#{connection.quote(value.to_json)}::jsonb"
        else
          connection.quote(value)
        end
      end

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

    values.length
  end

  def self.estimate_row_count(model)
    model.connection.select_value(
      'SELECT reltuples FROM pg_class WHERE relname = $1',
      'ROW ESTIMATE',
      [model.table_name]
    ).to_i
  end
end
