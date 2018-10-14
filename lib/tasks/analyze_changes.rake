desc 'Queue up automated analysis for versions added in a given timeframe.'
task :analyze_changes, [:start_date, :end_date] => [:environment] do |_t, args|
  # Kind of like find_each, but allows for ordered queries. We need this since
  # a) UUIDs are not really ordered and b) we are still live inserting data.
  def iterate_batches(collection, batch_size: 1000)
    offset = 0
    loop do
      items = collection.limit(batch_size).offset(offset)
      items.each {|item| yield item}
      break if items.count.zero?

      offset += batch_size
    end
  end

  start_date = args.key?(:start_date) ? Time.parse(args[:start_date]) : nil
  end_date = args.key?(:end_date) ? Time.parse(args[:end_date]) : nil
  puts "Searching for versions between #{start_date || 'now'} and #{end_date || 'now'}"

  versions = Version
    .where_in_unbounded_range('capture_time', [start_date, end_date])
    .order(capture_time: :asc)

  found_versions = 0
  queued_jobs = 0
  iterate_batches(versions) do |version|
    found_versions += 1
    unless version.change_from_previous
      AnalyzeChangeJob.perform_later(version)
      queued_jobs += 1
    end
  end

  puts "Queued analysis on #{queued_jobs} of #{found_versions} versions in timeframe."
end
