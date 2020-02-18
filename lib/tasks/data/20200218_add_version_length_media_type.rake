namespace :data do
  desc 'Set `length`, `media_type`, and `media_type_parameters` on all versions.'
  task :'20200218_add_version_length_media_type', [:force] => [:environment] do |_t, args|
    force = ['t', 'true', '1'].include? args.fetch(:force, '').downcase

    ActiveRecord::Migration.say_with_time('Updating length and media_type on versions...') do
      DataHelpers.with_activerecord_log_level(:error) do
        last_update = Time.now
        completed = 0
        total = Version.all.count

        DataHelpers.iterate_each(Version.all.order(created_at: :asc), batch_size: 500) do |version|
          update_version_media_length(version, force: force)
          completed += 1
          if Time.now - last_update > 2
            DataHelpers.log_progress(completed, total, description: 'versions updated')
            last_update = Time.now
          end
        end

        DataHelpers.log_progress(completed, total, end_line: true, description: 'versions updated')
        completed
      end
    end
  end

  def update_version_media_length(version, force: false)
    meta = version.source_metadata || {}
    set_version_media(version, meta, force)
    set_version_length(version, meta, force)
    version.save if version.changed?
  end

  def set_version_media(version, meta, force)
    return if version.media_type && !force

    media = meta['media_type'] || meta['content_type'] || meta['mime_type']
    encoding = meta['encoding']
    if media
      version.media_type = media
      version.media_type_parameters = "charset=#{encoding}" if encoding
    elsif meta['headers'].is_a?(Hash)
      media = meta['headers']['content-type'] || meta['headers']['Content-Type']
      version.content_type = media if media
    end
  end

  def set_version_length(version, meta, force)
    return if !version.uri || (version.length && !force)

    stored_meta = Archiver.store.get_metadata(version.uri)
    if stored_meta
      version.length = stored_meta[:size]
    elsif meta && meta['headers'].is_a?(Hash)
      header_length = meta['headers']['content-length'] || meta['headers']['Content-Length']
      version.length = header_length if header_length
    end
  end
end
