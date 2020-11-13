namespace :data do
  desc 'Set `content_length`, and `media_type` on all versions.'
  task :'20200218_add_version_length_media_type', [:force, :start_date, :end_date] => [:environment] do |_t, args|
    force = ['t', 'true', '1'].include? args.fetch(:force, '').downcase
    start_date = parse_time(args[:start_date], Time.new(2016, 1, 1))
    end_date = parse_time(args[:end_date], Time.now + 1.day)

    update_version_length_media_type(start_date, end_date, force: force)
  end

  def update_version_length_media_type(start_date, end_date = nil, force: false)
    end_date ||= start_date + 1.month
    progress_interval = $stdout.isatty ? 2 : 10

    ActiveRecord::Migration.say_with_time('Updating content_length and media_type on versions...') do
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
          changed = update_version_media_length(version, force: force)
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
    version.derive_media_type(force: force)
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

  def set_version_length(version, meta, force)
    return if !version.uri || (version.content_length && !force)

    stored_meta = Archiver.store.get_metadata(version.uri)
    if stored_meta
      version.content_length = stored_meta[:size]
    elsif meta && meta['headers'].is_a?(Hash)
      header_length = meta['headers']['content-length'] ||
                      meta['headers']['Content-Length']
      if header_length
        # Some records have `Content-Length: -1`, e.g:
        # http://web.archive.org/web/20161209185238id_/https://www.blm.gov/about/our-mission
        length = header_length.to_i
        version.content_length = length if length >= 0
      end
    end
  end

  def get_metadata_from_archive(version, force)
    if version.uri.present? && (version.content_length.nil? || version.media_type.nil? || force)
      data = get_metadata_from_url(version.uri)
      version.content_length = data[:size] unless version.content_length
      if data[:content_type] && !version.media_type
        version.derive_media_type(value: data[:content_type])
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
               puts "No response body for #{url}"
               nil
             end
      { size: size, content_type: response.headers['content-type'] }
    end
  end

  def parse_time(value, default)
    value ? Time.parse(value) : default
  end
end
