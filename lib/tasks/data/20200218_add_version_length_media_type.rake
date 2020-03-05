namespace :data do
  desc 'Set `content_length`, `media_type`, and `media_type_parameters` on all versions.'
  task :'20200218_add_version_length_media_type', [:force, :start_date, :end_date] => [:environment] do |_t, args|
    force = ['t', 'true', '1'].include? args.fetch(:force, '').downcase
    start_date = args[:start_date] ? Time.parse(args[:start_date]) : Time.new(2016, 1, 1)
    end_date = args[:end_date] && Time.parse(args[:end_date])

    update_version_length_media_type(start_date, end_date, force)
  end

  def update_version_length_media_type(start_date, end_date = nil, force = false)
    end_date ||= start_date + 1.month

    ActiveRecord::Migration.say_with_time('Updating content_length and media_type on versions...') do
      DataHelpers.with_activerecord_log_level(:error) do
        query = Version
          .where('created_at >= ? AND created_at < ?', start_date, end_date)
          .order(created_at: :asc)
        last_update = Time.now
        completed = 0
        fixed = 0
        total = query.count

        DataHelpers.iterate_each(query, batch_size: 500) do |version|
          changed = update_version_media_length(version, force: force)
          fixed += 1 if changed
          completed += 1
          if Time.now - last_update > 2
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

  def media_type_or_nil(type)
    cleaned = type.strip if type.is_a? String
    if /\A\w[\w!\#$&^_+\-.]+\/\w[\w!\#$&^_+\-.]+\z/.match? cleaned
      cleaned
    end
  end

  def print_validation_errors(record)
    puts 'Validation errors:'
    record.errors.each do |field, error|
      puts "  #{field}: #{error} (value: '#{record.attributes[field]}')"
      puts "    #{record.source_metadata}"
    end
  end

  def update_version_media_length(version, force: false)
    meta = version.source_metadata || {}
    set_version_media(version, meta, force)
    set_version_length(version, meta, force)
    get_metadata_from_archive(version, force)
    if version.changed?
      begin
        version.save!
      rescue ActiveRecord::RecordInvalid
        print_validation_errors(version)
        raise
      end
      true
    else
      false
    end
  end

  def set_version_media(version, meta, force)
    return if version.media_type && !force

    media = media_type_or_nil(meta['media_type']) ||
            media_type_or_nil(meta['content_type']) ||
            media_type_or_nil(meta['mime_type'])
    encoding = meta['encoding']
    if media
      version.media_type = media
      version.media_type_parameters = "charset=#{encoding}" if encoding
    elsif meta['headers'].is_a?(Hash)
      media = media_type_or_nil(meta['headers']['content-type']) ||
              media_type_or_nil(meta['headers']['Content-Type'])
      version.content_type = media if media
    end
  end

  def set_version_length(version, meta, force)
    return if !version.uri || (version.content_length && !force)

    stored_meta = Archiver.store.get_metadata(version.uri)
    if stored_meta
      version.content_length = stored_meta[:size]
    elsif meta && meta['headers'].is_a?(Hash)
      header_length = meta['headers']['content-length'] ||
                      meta['headers']['Content-Length']
      version.content_length = header_length if header_length
    end
  end

  def get_metadata_from_archive(version, force)
    if version.uri.present? && (version.content_length.nil? || version.media_type.nil? || force)
      data = get_metadata_from_url(version.uri)
      version.content_length = data[:size] unless version.content_length
      if data[:content_type] && !version.media_type
        version.content_type = data[:content_type]
        # Reset the media type if not valid so we can save.
        version.media_type = nil unless version.valid?
      end
    end
  end

  def get_metadata_from_url(url)
    if url.starts_with?('file://')
      data = File.stat(url[7..])
      { size: data.size, content_type: nil }
    else
      response = Archiver.retry_request do
        if url.include? '.s3.amazonaws.com/'
          HTTParty.head(url, timeout: 20)
        else
          HTTParty.get(url, timeout: 20)
        end
      end
      size = if response.headers['content-length']
               response.headers['content-length'].to_i
             elsif response.body
               response.body.bytes.length
             else
               puts "No response body for #{version.uri} (UUID: #{version.uuid})"
               nil
             end
      { size: size, content_type: response.headers['content-type'] }
    end
  end
end
