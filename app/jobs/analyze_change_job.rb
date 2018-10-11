class AnalyzeChangeJob < ApplicationJob
  queue_as :analysis

  QUESTIONABLE_URL = /\.(pdf|jpg|jpeg|png|bmp|gif|xls|xlsx|doc|docx)($|\?|#)/

  def perform(to_version, from_version = nil, compare_earliest = true)
    # This is a very narrow-purpose prototype! Most of the work should probably
    # move to web-monitoring-processing.
    change = if from_version
      Change.between(from: from_version, to: to_version)
    else
      to_version.ensure_change_from_previous
    end

    return unless is_analyzable?(change)

    analyze_change(change)

    if compare_earliest
      earliest_change = to_version.ensure_change_from_earliest
      analyze_change(earliest_change) if is_analyzable?(earliest_change)
    end
  end

  # This may shortly become a simple call to some processing server endpoint:
  # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/404
  def analyze_change(change)
    results = {}.with_indifferent_access
    priority = 0

    text_diff = Differ.for_type!('html_text_dmp').diff(change)['diff']
    text_diff_changes = text_diff.select {|operation| operation[0] != 0}
    results[:text_diff_hash] = hash_changes(text_diff_changes)
    results[:text_diff_count] = text_diff_changes.length
    results[:text_diff_ratio] = diff_ratio(text_diff)

    source_diff = Differ.for_type!('html_source_dmp').diff(change)['diff']
    diff_changes = source_diff.select {|operation| operation[0] != 0}
    results[:source_diff_hash] = hash_changes(diff_changes)
    results[:source_diff_count] = diff_changes.length
    results[:source_diff_ratio] = diff_ratio(source_diff)

    # A text diff change necessarily implies a source change; don't double-count
    if text_diff_changes.length > 0
      # TODO: ignore stop words and also consider special terms more heavily, ignore punctuation
      priority += 0.1 + 0.3 * priority_factor(results[:text_diff_ratio])
    elsif diff_changes.length > 0
      # TODO: eventually develop a more granular sense of change, either by
      # parsing or regex, where some source changes matter and some don't.
      priority += 0.1 * priority_factor(results[:source_diff_ratio])
    end

    links_diff = Differ.for_type!('links_json').diff(change)['diff']
    diff_changes = links_diff.select {|operation| operation[0] != 0}
    results[:links_diff_hash] = hash_changes(diff_changes)
    results[:links_diff_count] = diff_changes.length
    results[:links_diff_ratio] = diff_ratio(links_diff)
    if diff_changes.length > 0
      priority += 0.05 + 0.2 * priority_factor(results[:links_diff_ratio])
    end

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
    return 0.0 if operations.length == 0 || operations.length == 1 && operations[0] == 0

    characters = operations.reduce([0, 0]) do |counts, operation|
      code, text = operation
      counts[0] += text.length if code != 0
      counts[1] += text.length
      counts
    end

    characters[1] == 0 ? 0.0 : (characters[0] / characters[1].to_f).round(4)
  end

  def is_analyzable?(change)
    unless change && change.version.uuid != change.from_version.uuid
      Rails.logger.debug "Cannot analyze change #{change.try(:api_id)}; same versions"
      return false
    end

    unless is_fetchable?(change.version.uri)
      Rails.logger.debug "Cannot analyze with non-http(s) source: #{change.api_id} (#{change.version.uri})"
      return false
    end

    unless is_fetchable?(change.from_version.uri)
      Rails.logger.debug "Cannot analyze with non-http(s) source: #{change.api_id} (#{change.from_version.uri})"
      return false
    end

    # TODO: this will eventually be a proper field on `version`:
    # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/199
    from_metadata = change.from_version.source_metadata || {}
    to_metadata = change.version.source_metadata || {}
    from_media = from_metadata['content_type'] || from_metadata['mime_type'] || ''
    # FIXME: presume super old versionista data is text/html, since we didn't use to track mime type :(
    # This should probably also be fixed with the above issue.
    from_media = 'text/html' if from_media == '' && change.from_version.source_type == 'versionista'
    to_media = to_metadata['content_type'] || to_metadata['mime_type'] || ''
    if from_media.start_with?('text/') && to_media.start_with?('text/')
      # FIXME: this is a temporary fix for some very bad stuck jobs
      # Basically, the the rule above about assuming text/html for super-old
      # Versionista data can cause us to ask the diffing server to diff some
      # big binary data.
      if change.version.uri.match?(QUESTIONABLE_URL) || change.from_version.uri.match?(QUESTIONABLE_URL)
        Rails.logger.debug "Cannot analyze change #{change.api_id}; URL looks like maybe not HTML"
        return false
      end
      true
    else
      Rails.logger.debug "Cannot analyze change #{change.api_id}; non-text media type"
      false
    end
  end

  def is_fetchable?(url)
    url && (url.start_with?('http:') || url.start_with?('https:'))
  end

  def hash_changes(changes)
    Digest::SHA256.hexdigest(changes.to_json)
  end

  def annotator
    email = ENV['AUTO_ANNOTATION_USER']
    user = if email
      User.find_by(email: email)
    elsif !Rails.env.production?
      User.first
    end

    raise StandardError, 'Could not user to annotate changes' unless user

    user
  end
end
