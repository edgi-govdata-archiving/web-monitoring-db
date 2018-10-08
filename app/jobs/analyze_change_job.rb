class AnalyzeChangeJob < ApplicationJob
  queue_as :default

  def perform(to_id, from_id = nil, compare_earliest = true)
    # This is a very narrow-purpose prototype! Most of the work should probably
    # move to web-monitoring-processing.
    to_version = Version.find(to_id)
    change = if from_id
      Change.between(from: from_id, to: to_version)
    else
      to_version.change_from_previous
    end

    return unless is_analyzable(change)

    analyze_change(change)

    if compare_earliest
      earliest = to_version.page.versions.reorder(capture_time: :asc).where("capture_time > '2016-11-01T00:00:00'").first
      change_from_earliest = Change.between(from: earliest, to: to_version)
      analyze_change(change_from_earliest) if is_analyzable(change_from_earliest)
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

    source_diff = Differ.for_type!('html_source_dmp').diff(change)['diff']
    diff_changes = source_diff.select {|operation| operation[0] != 0}
    results[:source_diff_hash] = hash_changes(diff_changes)
    results[:source_diff_count] = diff_changes.length

    # A text diff change necessarily implies a source change; don't double-count
    if text_diff_changes.length > 0
      # TODO: ignore stop words and also consider special terms more heavily, ignore punctuation
      priority += 0.4
    elsif diff_changes.length > 0
      # TODO: eventually develop a more granular sense of change, either by
      # parsing or regex, where some source changes matter and some don't.
      priority += 0.1
    end

    links_diff = Differ.for_type!('links_json').diff(change)['diff']
    diff_changes = links_diff.select {|operation| operation[0] != 0}
    results[:links_diff_hash] = hash_changes(diff_changes)
    results[:links_diff_count] = diff_changes.length
    priority += 0.25 if diff_changes.length > 0

    results[:priority] = priority

    change.annotate(results, annotator)
    change.save!
  end

  def is_analyzable(change)
    unless change && change.version.uuid != change.from_version.uuid
      Rails.logger.debug "Cannot analyze change #{change.try(:api_id)}; same versions"
      return false
    end

    # TODO: this will eventually be a proper field on `version`:
    # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/199
    from_media = change.from_version.source_metadata['content_type'] || change.from_version.source_metadata['mime_type'] || ''
    # FIXME: presume super old versionista data is text/html, since we didn't use to track mime type :(
    # This should probably also be fixed with the above issue.
    from_media = 'text/html' if from_media == '' && change.from_version.source_type == 'versionista'
    to_media = change.version.source_metadata['content_type'] || change.version.source_metadata['mime_type'] || ''
    if from_media.start_with?('text/') && to_media.start_with?('text/')
      true
    else
      Rails.logger.debug "Cannot analyze change #{change.api_id}; non-text media type"
      false
    end
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
