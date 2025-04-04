desc 'Queue up automated analysis for versions added in a given timeframe.'
task :analyze_changes, [:start_date, :end_date] => [:environment] do |_t, args|
  start_date = args.key?(:start_date) ? Time.parse(args[:start_date]) : nil
  end_date = args.key?(:end_date) ? Time.parse(args[:end_date]) : nil
  puts "Searching for versions between #{start_date || 'now'} and #{end_date || 'now'}"

  versions = Version
    .where_in_unbounded_range('capture_time', [start_date, end_date])
    .order(capture_time: :asc)

  found_versions = 0
  queued_jobs = 0
  DataHelpers.iterate_each(versions, batch_size: 1000) do |version|
    found_versions += 1
    if version.different? && version.change_from_previous.nil?
      AnalyzeChangeJob.perform_later(version)
      queued_jobs += 1
    end
  end

  puts "Queued analysis on #{queued_jobs} of #{found_versions} versions in timeframe."
end
