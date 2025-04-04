namespace :data do
  desc 'Ensure the names of headers in Version records are downcased.'
  task :'20250330_downcase_header_names', [:start_date, :end_date] => [:environment] do |_t, args|
    start_date = parse_time(args[:start_date], Time.new(2010, 1, 1))
    end_date = parse_time(args[:end_date], Time.now + 1.day)

    ActiveRecord::Migration.say_with_time('Downcasing header names...') do
      DataHelpers.with_activerecord_log_level(:error) do
        progress = DataHelpers::ProgressLogger.new(Version, interval: 10.seconds)
        changed = 0

        version_batches(Version.where(capture_time: start_date...end_date), batch_size: 200) do |batch|
          changed += DataHelpers.bulk_update(batch, [:headers]) do |version|
            progress.increment

            unless version.headers.blank?
              normalized = Version.normalize_value_for(:headers, version.headers)
              [normalized] if normalized != version.headers
            end
          end
        end

        progress.complete
        changed
      end
    end
  end

  # It turns out that the `.ordered` method we have for Version is more than
  # 10x faster than AR's `in_batches`, even when using an optimized `cursor`
  # parameter. This *really* matters given the size of this table.
  def version_batches(collection, batch_size: 1000, &)
    anchor = nil
    loop do
      batch = collection.ordered(:capture_time, point: anchor).limit(batch_size)
      anchor = batch.to_a.last
      break unless anchor

      yield batch
    end
  end
end
