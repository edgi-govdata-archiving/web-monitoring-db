namespace :data do
  desc 'Fill in `headers` on versions from `source_metadata.headers`.'
  task :'20210605_fill_version_headers_from_source_metadata', [:force, :start_date, :end_date] => [:environment] do |_t, args|
    force = ['t', 'true', '1'].include? args.fetch(:force, '').downcase
    start_date = parse_time(args[:start_date], Time.new(2016, 1, 1))
    end_date = parse_time(args[:end_date], Time.now + 1.day)

    fill_version_headers(start_date, end_date, force: force)
  end

  def fill_version_headers(start_date, end_date = nil, force: false)
    end_date ||= start_date + 1.month
    progress_interval = $stdout.isatty ? 2 : 10

    ActiveRecord::Migration.say_with_time('Filling in headers on versions...') do
      DataHelpers.with_activerecord_log_level(:error) do
        query = Version
        last_update = Time.now
        completed = 0
        fixed = 0
        total = query
          .where('created_at >= ? AND created_at < ?', start_date, end_date)
          .order(created_at: :asc)
          .count

        DataHelpers.iterate_time(query, start_time: start_date, end_time: end_date) do |version|
          changed = update_version_headers(version, force: force)
          fixed += 1 if changed
          completed += 1
          if Time.now - last_update > progress_interval
            message = "#{fixed} updated, #{completed}"
            DataHelpers.log_progress(message, total, description: 'versions processed')
            last_update = Time.now
          end
        end

        message = "#{fixed} updated, #{completed}"
        DataHelpers.log_progress(message, total, end_line: true, description: 'versions processed')
        completed
      end
    end
  end

  def update_version_headers(version, force: false)
    return false if version.headers && !version.headers.empty? && !force
    return false unless version.source_metadata

    version.headers = version.source_metadata['headers']
    new_meta = version.source_metadata.clone
    new_meta.delete('headers')
    version.source_metadata = new_meta

    if version.changed?
      version.save!
      true
    else
      false
    end
  end
end
