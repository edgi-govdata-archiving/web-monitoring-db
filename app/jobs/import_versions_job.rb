class ImportVersionsJob < ApplicationJob
  queue_as :import

  # TODO: wrap in transaction?
  def perform(import)
    @import = import
    log(object: @import, operation: :started)
    @import.update(status: :processing)
    @added = []

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

    if AnalyzeChangeJob.supported?
      @added.uniq(&:uuid).each do |version|
        AnalyzeChangeJob.perform_later(version) if version.different?
      end
    else
      Rails.logger.warn "Import #{import.id}: Auto-analysis is not configured; AnalyzeChangeJobs were not scheduled for imported versions."
    end
  end

  def import_raw_data(raw_data)
    last_update = Time.now
    each_json_line(raw_data) do |record, row, row_count|
      begin
        Rails.logger.info("Importing row #{row}/#{row_count}...") if Rails.env.development? && (row % 25).zero?
        import_record(record, row)
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

      # Jobs can be *long*, so make sure updates are persisted periodically.
      next unless Time.now - last_update > 5

      # save! will set updated_at, but only if something else has changed.
      # Explicitly change updated_at so it always gets set, even if we don't
      # have any other messages to persist.
      @import.updated_at = last_update = Time.now
      @import.save!
    end
    log(object: @import, operation: :finished)
  end

  def import_record(record, row)
    page = page_for_record(record, create: @import.create_pages, row:)
    unless page
      warn "Skipped unknown URL: #{record['page_url']}@#{record['capture_time']}"
      return
    end
    unless page.active?
      warn "Skipped inactive URL: #{page.url}"
      return
    end

    existing_version = page.versions.find_by(
      capture_time: record['capture_time'],
      source_type: record['source_type']
    )

    if existing_version && @import.skip_existing_records?
      log(object: existing_version, operation: :skipped_existing, row:)
      return
    end

    version = version_for_record(record, existing_version, @import.update_behavior)
    version.page = page

    if version.body_url.nil?
      if record['content']
        # TODO: upload content
        raise Api::NotImplementedError, 'Raw content uploading not implemented yet.'
      end
    elsif !Archiver.already_archived?(version.body_url) || !version.body_hash
      result = Archiver.archive(version.body_url, expected_hash: version.body_hash)
      version.body_hash = result[:hash]
      version.content_length = result[:length]
      if result[:url] != version.body_url
        version.source_metadata ||= {}
        version.source_metadata['original_url'] = version.body_url
        version.body_url = result[:url]
      end
    end

    if @import.skip_unchanged_versions? && version_changed?(version)
      log(object: version, operation: :skipped_identical, row:)
      warn "Skipped version identical to previous. URL: #{page.url}, capture_time: #{version.capture_time}, source_type: #{version.source_type}"
      return
    end

    version.validate!
    version.update_different_attribute(save: false)
    version.save

    if existing_version
      log(object: version, operation: @import.update_behavior, row:)
    else
      log(object: version, operation: :created, row:)
    end

    @added << version unless existing_version
  end

  def version_for_record(record, existing_version = nil, update_behavior = 'replace')
    # TODO: Remove line 74 below once full transition from 'page_title' to 'title'
    # is complete
    record['title'] = record['page_title'] if record.key?('page_title')
    record['url'] = record['page_url'] if record.key?('page_url')
    record['body_url'] = record['uri'] if record.key?('uri')
    record['body_hash'] = record['version_hash'] if record.key?('version_hash')
    record['body_hash'] = record['hash'] if record.key?('hash')
    if record.key?('source_metadata')
      meta = record['source_metadata']
      record['media_type'] = meta['mime_type'] if meta.key?('mime_type')
      unless record.key?('content_length')
        length = meta.dig('headers', 'Content-Length')
        record['content_length'] = length if length.present?
      end

      # Find headers in source_metadata if missing from the top level.
      # TODO: remove once full transition to top level headers is comlete.
      if meta.key?('headers') && !record.key?('headers')
        record['headers'] = meta['headers']
        meta.delete('headers')
      end
    end
    disallowed = ['id', 'uuid', 'created_at', 'updated_at']
    allowed = Version.attribute_names - disallowed

    if existing_version
      values =
        if update_behavior == 'merge'
          new_values = record.slice(*allowed)
          if new_values.key?('source_metadata')
            new_values['source_metadata'] = existing_version.source_metadata
              .merge(new_values['source_metadata'])
          end
          new_values
        else
          allowed.to_h {|key| [key, record[key]]}
        end

      existing_version.assign_attributes(values)
      existing_version
    else
      values = record.select {|key, _| allowed.include?(key) || key == 'uuid'}
      Version.new(values)
    end
  end

  def page_for_record(record, create: true, row:)
    validate_present!(record, 'page_url')
    validate_kind!([String], record, 'page_url')
    validate_kind!([Array, NilClass], record, 'page_maintainers')
    validate_kind!([Array, NilClass], record, 'page_tags')
    validate_present!(record, 'capture_time')
    validate_kind!([String], record, 'capture_time')

    url = record['page_url']

    capture_time = Time.parse(record['capture_time'])
    existing_page = Page.find_by_url(url, at_time: capture_time)
    page = if existing_page
             log(object: existing_page, operation: :found, row:)
             existing_page
           elsif create
             new_page = Page.create!(url:)
             log(object: new_page, operation: :created, row:)
             new_page
           end

    return nil unless page

    (record['page_maintainers'] || []).each {|name| page.add_maintainer(name)}
    (record['page_tags'] || []).each {|name| page.add_tag(name)}

    # If the page was not an *exact* URL match, add the URL to the page.
    # (`page.find_by_url` used above will match by `url_key`, too.)
    page.urls.find_or_create_by(url:)
    # TODO: Add URLs from redirects automatically. The main blocker for
    # this at the moment is the following situation:
    #
    #   Two pages, A=https://example.com/about
    #              B=https://example.com/about/locations
    #   Page B is removed, but instead of returning a 404 or 403 status
    #     code, it starts redirecting to Page A.
    #
    # This is unfortunately not uncommon, so we need some heuristics to
    # account for it, e.g. URL does not already belong to another page.

    page
  end

  private

  def warn(message)
    @import.processing_warnings << message
    Rails.logger.warn "Import #{@import.id} #{message}"
  end

  def log(object:, operation:, row: nil)
    object_name = object.class.name
    object_id = if object.respond_to? :uuid
                  object.uuid
                else
                  object.id
                end

    conjugated_operation = {
      'merge' => 'merged',
      'replace' => 'replaced',
      'skip' => 'skipped'
    }.fetch(operation, operation)

    Rails.logger.debug("[import=#{@import.id}]#{row ? "[row=#{row}]" : ''} #{conjugated_operation.capitalize} #{object_name} #{object_id}")
  end

  # iterate through a JSON array or series of newline-delimited JSON objects
  def each_json_line(raw_json)
    record_set = nil

    begin
      record_set = JSON.parse(raw_json)
      # Coerce to array in case it was a JSON stream with only a single record
      record_set = [record_set] unless record_set.is_a?(Array)
    rescue JSON::ParserError
      record_set = raw_json.split("\n")
    end

    row_count = record_set.length
    record_set.each_with_index do |line, row|
      if line.is_a? String
        next if line.empty?

        yield JSON.parse(line), row, row_count
      else
        yield line, row, row_count
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

  def version_changed?(version)
    return true if version.body_hash.nil?

    previous = version.page.versions
      .where(source_type: version.source_type)
      .where('capture_time < ?', version.capture_time)
      .order(capture_time: :desc)
      .first

    version.body_hash == previous.try(:body_hash)
  end
end
