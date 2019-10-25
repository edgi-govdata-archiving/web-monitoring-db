namespace :data do
  # If the database is too big, use the date filters to break the work into
  # smaller, more time-constrained chunks.
  desc 'Migrate raw Versionista data stored in S3 to new EDGI-owned bucket.'
  task :'20180926_move_versionista_s3_data', [:start_date, :end_date] => [:environment] do |_t, args|
    start_date = args[:start_date] && Time.parse(args[:start_date])
    end_date = args[:end_date] && Time.parse(args[:end_date])

    new_versionista_prefix = 'https://edgi-wm-versionista.s3.amazonaws.com/'
    old_versionista_prefixes = [
      'https://edgi-versionista-archive.s3.amazonaws.com/',
      'https://edgi-versionista-archive.s3-us-west-2.amazonaws.com/',
      'https://s3-us-west-2.amazonaws.com/edgi-versionista-archive/'
    ]

    new_archive_prefix = 'https://edgi-wm-archive.s3.amazonaws.com/'
    old_archive_prefixes = [
      'https://edgi-web-monitoring-db.s3.amazonaws.com/',
      'https://edgi-web-monitoring-db.s3-us-east-1.amazonaws.com/',
      'https://s3-us-east-1.amazonaws.com/edgi-web-monitoring-db/'
    ]

    ActiveRecord::Migration.say_with_time('Updating `uri` on versions to new S3 buckets') do
      count = 0
      DataHelpers.with_activerecord_log_level(:error) do
        old_versionista_prefixes.each do |prefix|
          count += replace_uri_prefix(prefix, new_versionista_prefix, start_date, end_date)
        end

        old_archive_prefixes.each do |prefix|
          count += replace_uri_prefix(prefix, new_archive_prefix, start_date, end_date)
        end
      end

      count
    end
  end

  def replace_uri_prefix(old_prefix, new_prefix, start_date = nil, end_date = nil)
    start_at = old_prefix.length
    query = Version
      .where("uri LIKE '#{old_prefix}%'")
      .order(created_at: :asc)
    query = query.where('capture_time >= ?', start_date) if start_date
    query = query.where('capture_time <= ?', end_date) if end_date

    # We're updating what we're querying on, so just repeat until no results.
    updated = 0
    loop do
      values = query.limit(500).collect do |version|
        "('#{version.uuid}', '#{new_prefix}#{version.uri[start_at..-1]}')"
      end

      updated += values.length
      print "   Updating #{updated} with prefix '#{old_prefix}'...\r"
      STDOUT.flush

      if values.empty?
        # We have to print here to clear the \r at end of the last line
        puts ''
        break
      end

      Version.connection.execute(
        <<-QUERY
          UPDATE
            versions
          SET
            uri = valueset.uri,
            updated_at = #{Version.connection.quote(Time.now)}
          FROM
            (values #{values.join(',')}) as valueset(uuid, uri)
          WHERE
            versions.uuid = valueset.uuid::uuid
        QUERY
      )
    end

    updated
  end
end
