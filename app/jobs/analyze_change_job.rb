class AnalyzeChangeJob < ApplicationJob
  queue_as :analysis

  # text/* media types are allowed, so only non-text types need be explicitly
  # allowed and only text types need be explicitly disallowed.
  ALLOWED_MEDIA = [
    # HTML should be text/html, but these are also common.
    'appliction/html',
    'application/xhtml',
    'application/xhtml+xml',
    'application/xml',
    'application/xml+html',
    'application/xml+xhtml'
  ].freeze

  DISALLOWED_MEDIA = [
    'text/calendar'
  ].freeze

  DISALLOWED_EXTENSIONS = [
    '.jpg',
    '.pdf',
    '.athruz',
    '.avi',
    '.doc',
    '.docbook',
    '.docx',
    '.dsselect',
    '.eps',
    '.epub',
    '.exe',
    '.gif',
    '.jpeg',
    '.jpg',
    '.kmz',
    '.m2t',
    '.mov',
    '.mp3',
    '.mpg',
    '.pdf',
    '.png',
    '.ppt',
    '.pptx',
    '.radar',
    '.rtf',
    '.wmv',
    '.xls',
    '.xlsm',
    '.xlsx',
    '.xml',
    '.zip'
  ].freeze

  # Determine whether this job is supported with the current configuration
  def self.supported?
    ENV['AUTO_ANNOTATION_USER'].present? &&
      Differ.for_type('html_text_dmp').present? &&
      Differ.for_type('html_source_dmp').present? &&
      Differ.for_type('links_json').present?
  end

  def perform(to_version, from_version = nil, compare_earliest = true)
    # This is a very narrow-purpose prototype! Most of the work should probably
    # move to web-monitoring-processing.
    change = if from_version
               Change.between(from: from_version, to: to_version)
             else
               to_version.ensure_change_from_previous
             end

    return unless analyzable?(change)

    analyze_change(change)

    if compare_earliest
      earliest_change = to_version.ensure_change_from_earliest
      analyze_change(earliest_change) if analyzable?(earliest_change)
    end
  end

  # This may shortly become a simple call to some processing server endpoint:
  # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/404
  def analyze_change(change)
    results = {}.with_indifferent_access
    priority = 0

    text_diff = Differ.for_type!('html_text_dmp').diff(change)['diff']
    text_diff_changes = text_diff.reject {|operation| operation[0] == 0}
    results[:text_diff_hash] = hash_changes(text_diff_changes)
    results[:text_diff_count] = text_diff_changes.length
    results[:text_diff_length] = text_diff_changes.sum {|_code, text| text.length}
    results[:text_diff_ratio] = diff_ratio(text_diff)

    source_diff = Differ.for_type!('html_source_dmp').diff(change)['diff']
    diff_changes = source_diff.reject {|operation| operation[0] == 0}
    results[:source_diff_hash] = hash_changes(diff_changes)
    results[:source_diff_count] = diff_changes.length
    results[:source_diff_length] = diff_changes.sum {|_code, text| text.length}
    results[:source_diff_ratio] = diff_ratio(source_diff)

    # A text diff change necessarily implies a source change; don't double-count
    if !text_diff_changes.empty?
      # TODO: ignore stop words and also consider special terms more heavily, ignore punctuation
      priority += 0.1 + 0.3 * priority_factor(results[:text_diff_ratio])
    elsif !diff_changes.empty?
      # TODO: eventually develop a more granular sense of change, either by
      # parsing or regex, where some source changes matter and some don't.
      priority += 0.1 * priority_factor(results[:source_diff_ratio])
    end

    links_diff = Differ.for_type!('links_json').diff(change)['diff']
    diff_changes = links_diff.reject {|operation| operation[0] == 0}
    results[:links_diff_hash] = hash_changes(diff_changes)
    results[:links_diff_count] = diff_changes.length
    results[:links_diff_ratio] = diff_ratio(links_diff)
    unless diff_changes.empty?
      priority += 0.05 + 0.2 * priority_factor(results[:links_diff_ratio])
    end

    # If we know a version represents a *server* error (not, say, a 404), then
    # deprioritize it. These are largely intermittent.
    # TODO: can we look at past versions to see whether the error is sustained?
    # TODO: relatedly, bump up priority for sustained 4xx errors
    priority = [0.1, priority].min if version_status(change.version) >= 500 ||
                                      version_status(change.from_version) >= 500 ||
                                      looks_like_error(results[:text_diff_ratio], text_diff)

    results[:priority] = priority.round(4)

    change.annotate(results, annotator)
    change.save!
  end

  # Calculate a multiplier for priority based on a ratio representing the amount
  # of change. This is basically applying a logorithmic curve to the ratio.
  def priority_factor(ratio)
    Math.log(1 + (Math::E - 1) * ratio)
  end

  def diff_ratio(operations)
    return 0.0 if operations.empty? || operations.length == 1 && operations[0] == 0

    characters = operations.each_with_object([0, 0]) do |operation, counts|
      code, text = operation
      counts[0] += text.length if code != 0
      counts[1] += text.length
    end

    characters[1] == 0 ? 0.0 : (characters[0] / characters[1].to_f).round(4)
  end

  def analyzable?(change)
    unless change && change.version.uuid != change.from_version.uuid
      Rails.logger.debug "Cannot analyze change #{change.try(:api_id)}; same versions"
      return false
    end

    unless fetchable?(change.version.uri)
      Rails.logger.debug "Cannot analyze with non-http(s) source: #{change.api_id} (#{change.version.uri})"
      return false
    end

    unless fetchable?(change.from_version.uri)
      Rails.logger.debug "Cannot analyze with non-http(s) source: #{change.api_id} (#{change.from_version.uri})"
      return false
    end

    if diffable_media?(change.version) && diffable_media?(change.from_version)
      true
    else
      Rails.logger.debug "Cannot analyze change #{change.api_id}; non-text media type"
      false
    end
  end

  def fetchable?(url)
    url && url.start_with?('http:', 'https:')
  end

  def diffable_media?(version)
    # TODO: this will eventually be a proper field on `version`:
    # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/199
    meta = version.source_metadata || {}
    media = meta['media_type'] || meta['content_type'] || meta['mime_type']
    if !media && meta['headers'].is_a?(Hash)
      media = meta['headers']['content-type'] || meta['headers']['Content-Type']
    end

    if media
      media = media.split(';', 2)[0]
      ALLOWED_MEDIA.include?(media) || (
        media.start_with?('text/') && !DISALLOWED_MEDIA.include?(media)
      )
    elsif !require_media_type?
      allowed_extension?(version.capture_url)
    else
      false
    end
  end

  def allowed_extension?(url)
    extension = Addressable::URI.parse(url).try(:extname)
    !extension || !DISALLOWED_EXTENSIONS.include?(extension)
  end

  def hash_changes(changes)
    Digest::SHA256.hexdigest(changes.to_json)
  end

  def annotator
    email = ENV['AUTO_ANNOTATION_USER']
    user = if email.present?
             User.find_by(email: email)
           elsif !Rails.env.production?
             User.first
           end

    raise StandardError, 'Could not find user to annotate changes' unless user

    user
  end

  def require_media_type?
    if @require_media_type.nil?
      @require_media_type = to_bool(ENV['ANALYSIS_REQUIRE_MEDIA_TYPE'])
    end
    @require_media_type
  end

  def to_bool(text)
    text = (text || '').downcase
    ['true', 't', '1'].include? text
  end

  # If present in the metadata, get the HTTP status code as a number
  def version_status(version)
    meta = version.source_metadata || {}
    (meta['status_code'] || meta['error_code']).to_i
  end

  # Heuristically identify versions that were errors, but had 2xx status codes
  def looks_like_error(text_ratio, text_diff)
    return false if text_ratio < 0.9

    texts = text_diff.each_with_object(old: '', new: '') do |operation, texts_memo|
      texts_memo[:old] += operation[1] if operation[0] <= 0
      texts_memo[:new] += operation[1] if operation[0] >= 0
    end

    texts.each do |_key, text|
      text = text.downcase
      # Based on version 8b52f47a-e1d7-4098-8087-87f71a9fc0b0
      return true if text.include?('error connecting to apache tomcat instance') &&
                     text.include?('no connection could be made')
    end

    false
  end
end
