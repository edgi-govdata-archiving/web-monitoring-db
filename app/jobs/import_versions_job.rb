class ImportVersionsJob < ApplicationJob
  queue_as :default

  # TODO: wrap in transaction?
  def perform(import)
    Rails.logger.debug "Running Import \##{import.id}"
    @import = import
    @import.update(status: :processing)

    begin
      import_raw_data(@import.load_data)
    rescue StandardError => error
      @import.processing_errors << if Rails.env.development?
                                     "Import #{import.id}: #{error.message}"
                                   else
                                     "Import #{import.id}: Unknown error occurred"
                                   end
      Rails.logger.error "Import #{import.id}: #{error.message}"
      raise
    ensure
      @import.status = :complete
      @import.save
    end
  end

  def import_raw_data(raw_data)
    total_rows = raw_data.split("\n").length
    each_json_line(raw_data) do |record, row|
      begin
        puts "Importing row #{row+1}/#{total_rows}..." if ((row+1) % 25 == 0)
        import_record(record)
      rescue Api::ApiError => error
        @import.processing_errors << "Row #{row}: #{error.message}"
      rescue ActiveModel::ValidationError => error
        messages = error.model.errors.full_messages.join(', ')
        @import.processing_errors << "Row #{row}: #{messages}"
      rescue ActiveRecord::RecordInvalid => error
        messages = error.record.errors.full_messages.join(', ')
        @import.processing_errors << "Row #{row}: #{messages}"
      rescue StandardError => error
        @import.processing_errors << if Rails.env.development? || Rails.env.test?
                                       "Row #{row}: #{error.message}"
                                     else
                                       "Row #{row}: Unknown error occurred"
                                     end
        Rails.logger.error "Import #{@import.id} Row #{row}: #{error.message}"
      end
    end
  end

  def import_record(record)
    page = page_for_record(record, create: @import.create_pages)
    unless page
      warn "Skipped unknown URL: #{record['page_url']}@#{record['capture_time']}"
      return
    end

    existing = page.versions.find_by(
      capture_time: record['capture_time'],
      source_type: record['source_type']
    )

    return if existing && @import.skip_existing_records?
    version = version_for_record(record, existing, @import.update_behavior)
    version.page = page

    if version.uri.nil?
      if record['content']
        # TODO: upload content
        raise Api::NotImplementedError, 'Raw content uploading not implemented yet.'
      end
    elsif !Archiver.already_archived?(version.uri) || !version.version_hash
      result = Archiver.archive(version.uri, expected_hash: version.version_hash)
      version.version_hash = result[:hash]
      if result[:url] != version.uri
        version.source_metadata['original_url'] = version.uri
        version.uri = result[:url]
      end
    end

    version.validate!
    version.save
  end

  def version_for_record(record, existing_version = nil, update_behavior = 'replace')
    # TODO: Remove line 74 below once full transition from 'page_title' to 'title'
    # is complete
    record['title'] = record['page_title'] if record.key?('page_title')
    record['capture_url'] = record['page_url'] if record.key?('page_url')
    disallowed = ['id', 'uuid', 'created_at', 'updated_at']
    allowed = Version.attribute_names - disallowed

    if existing_version
      values =
        if update_behavior == 'merge'
          new_values = record.select {|key, _| allowed.include?(key)}
          if new_values.key?('source_metadata')
            new_values['source_metadata'] = existing_version.source_metadata
              .merge(new_values['source_metadata'])
          end
          new_values
        else
          Hash[allowed.collect {|key| [key, record[key]]}]
        end

      existing_version.assign_attributes(values)
      existing_version
    else
      values = record.select {|key, _| allowed.include?(key) || key == 'uuid'}
      Version.new(values)
    end
  end

  def page_for_record(record, create: true)
    validate_present!(record, 'page_url')
    validate_kind!([String], record, 'page_url')
    validate_kind!([Array, NilClass], record, 'page_maintainers')
    validate_kind!([Array, NilClass], record, 'page_tags')

    url = record['page_url']
    page = Page.find_by_url(url) || if create
                                      Page.create!(url: url)
                                    else
                                      return nil
                                    end

    (record['page_maintainers'] || []).each {|name| page.add_maintainer(name)}
    page.add_maintainer(record['site_agency']) if record.key?('site_agency')
    (record['page_tags'] || []).each {|name| page.add_tag(name)}
    page.add_tag("site:#{record['site_name']}") if record.key?('site_name')

    page
  end

  private

  def warn(message)
    @import.processing_warnings << message
    Rails.logger.warn "Import #{@import.id} #{message}"
  end

  # iterate through a JSON array or series of newline-delimited JSON objects
  def each_json_line(raw_json)
    record_set = nil

    begin
      record_set = JSON.parse(raw_json)
      # If could have been a JSON stream with only a single record
      record_set = [record_set] unless record_set.is_a?(Array)
    rescue JSON::ParserError
      record_set = raw_json.split("\n")
    end

    record_set.each_with_index do |line, row|
      if line.is_a? String
        next if line.empty?
        yield JSON.parse(line), row
      else
        yield line, row
      end
    end
  end

  def validate_present!(record, field_name)
    raise Api::InputError, "`#{field_name}` is missing" unless record.key?(field_name)
  end

  def validate_kind!(kinds, record, field_name)
    kinds = [kinds] unless kinds.is_a?(Enumerable)
    value = record[field_name]

    unless kinds.any? {|kind| value.is_a?(kind)}
      names = kinds.collect do |kind|
        kind == NilClass ? 'null' : "a #{kind.name}"
      end.join(' or ')
      raise Api::InputError, "`#{field_name}` must be #{names}, not `#{value.class.name}`"
    end
  end
end
