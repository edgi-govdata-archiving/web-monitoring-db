namespace :data do
  desc 'Migrate raw Versionista data stored in S3 to new EDGI-owned bucket.'
  task :'20180926_move_versionista_s3_data', [] => [:environment] do
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
      Version.transaction do
        old_versionista_prefixes.each do |prefix|
          count += replace_uri_prefix(prefix, new_versionista_prefix)
        end

        old_archive_prefixes.each do |prefix|
          count += replace_uri_prefix(prefix, new_archive_prefix)
        end
      end

      count
    end
  end

  def replace_uri_prefix(old_prefix, new_prefix)
    start_at = old_prefix.length
    query = Version
      .where("uri LIKE '#{old_prefix}%'")
      .order(created_at: :asc)

    # We're updating what we're querying on, so just repeat until no results.
    updated = 0
    loop do
      start_count = updated
      query.limit(1000).each do |version|
        version.update(uri: new_prefix + version.uri[start_at..-1])
        updated += 1
      end
      break if updated == start_count
    end

    updated
  end
end
