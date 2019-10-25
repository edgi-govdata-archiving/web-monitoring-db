# Tools for working with database data. These are mostly used in rake tasks and migrations.
module DataHelpers
  # Log and rewrite a progress indicator like `  x/y completed`
  def self.log_progress(completed, total, suffix: 'completed', end_line: false)
    ending = end_line ? "\n" : "\r"
    STDOUT.write("   #{completed}/#{total} #{suffix}#{ending}")
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
  def self.iterate_each(collection, batch_size: 500)
    offset = 0
    loop do
      items = collection.limit(batch_size).offset(offset)
      items.each {|item| yield item}
      break if items.count.zero?

      offset += batch_size
    end
  end
end
