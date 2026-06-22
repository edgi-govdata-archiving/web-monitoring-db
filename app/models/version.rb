# frozen_string_literal: true

class Version < ApplicationRecord
  include UuidPrimaryKey
  include SimpleTitle

  MEDIA_TYPE_PATTERN = /\A\w[\w!\#$&^_+\-.]+\/\w[\w!\#$&^_+\-.]+\z/

  # Commonly used, but not quite correct media types.
  MEDIA_TYPE_SYNONYMS = {
    # HTML
    'application/html' => 'text/html',
    # XHTML (it would be nice to combine this with HTML most of the time, but alas, not always)
    'application/xhtml' => 'application/xhtml+xml',
    'application/xml+html' => 'application/xhtml+xml',
    'application/xml+xhtml' => 'application/xhtml+xml',
    'text/xhtml' => 'application/xhtml+xml',
    'text/xhtml+xml' => 'application/xhtml+xml',
    'text/xml+html' => 'application/xhtml+xml',
    'text/xml+xhtml' => 'application/xhtml+xml',
    # PDF
    'application/x-pdf' => 'application/pdf',
    # JS
    'application/javascript' => 'text/javascript',
    'application/x-javascript' => 'text/javascript',
    'text/x-javascript' => 'text/javascript',
    # JSON
    'text/x-json' => 'application/json',
    'text/json' => 'application/json',
    # WOFF
    'application/font-woff' => 'font/woff', # Used to be standard, now deprecated
    'application/x-font-woff' => 'font/woff', # Used by Chrome pre-standardization
    # JPEG
    'image/jpg' => 'image/jpeg',
    # MS Office
    # https://docs.microsoft.com/en-us/previous-versions/office/office-2007-resource-kit/ee309278(v=office.12)
    # This is the only mis-named one we've seen, and I'm wary of setting
    # similar ones because they might override future legitimate types.
    'application/xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  }.freeze

  # Lookup for standardized HTTP status messages, e.g. "404 Not Found".
  STANDARD_STATUS_MESSAGES = Set.new(
    Rack::Utils::HTTP_STATUS_CODES.collect do |code, message|
      "#{code} #{message.downcase}"
    end
  ).freeze

  # NOTE: Versions *may* be orphaned from pages. This is pretty rare, but is a
  # legitimate scenario.
  belongs_to :page, foreign_key: :page_uuid, optional: true, inverse_of: :versions, touch: true
  has_many :tracked_changes, class_name: 'Change', foreign_key: 'uuid_to'

  # HTTP header names are case-insensitive. Store them lower-case for easy lookups/comparisons.
  normalizes :headers, with: ->(h) { h.transform_keys { |k| k.to_s.downcase } }
  before_create :derive_media_type
  before_create :derive_content_length
  after_create :sync_page_title
  validates :status,
            allow_nil: true,
            inclusion: { in: 100...600, message: 'is not between 100 and 599' }
  validates :media_type,
            allow_nil: true,
            format: {
              with: MEDIA_TYPE_PATTERN,
              message: 'must be a media type, like `text/plain`, and *not* ' \
                       'include parameters, like `; charset=utf-8`'
            }
  validates :content_length,
            allow_nil: true,
            numericality: { greater_than_or_equal_to: 0 }

  # Order a query by the combination of a field (e.g. capture_time) and uuid.
  # You can optionally set a point to start from (a Version instance or an array
  # of the field value and the record's UUID).
  # Used for range-based pagination instead of offset-based pagination.
  #
  # IMPORTANT: there should always be a compound index on the field you are
  # are sorting by + uuid. e.g. to sort by capture_time, you should have an
  # index on (capture_time, uuid).
  #
  # Usage:
  #   # Get the first 100 records in capture_time order
  #   Version.ordered(:capture_time).limit(100)
  #
  #   # Get the 100 records before the record with given capture_time and uuid
  #   Version.ordered(:capture_time, point: [<Time>, '<uuid>'], direction: :desc)
  #
  #   # Get the 100 records before the given record.
  #   anchor = Version.find('<uuid>')
  #   Version.ordered(:capture_time, point: anchor, direction: :desc).limit(100)
  def self.ordered(field, point: nil, direction: :asc)
    point = [point[field], point[primary_key]].compact if point.is_a?(Version)

    raise Api::InputError, 'Invalid query sorting point' if point && point.length != 2
    # Only allow fields where there is an index on `(field, uuid)`.
    unless [:capture_time, :created_at].include?(field)
      raise Api::InputError, 'Versions can only be sorted by `capture_time` or `created_at`'
    end

    query = reorder({ field => direction, uuid: direction })
    if point
      fields = [field, primary_key].collect {|f| "#{table_name}.#{f}"}
      comparator = direction == :asc ? '>' : '<'
      query.where("(#{fields.join(',')}) #{comparator} (?, ?)", *point)
    else
      query
    end
  end

  def earliest
    page.versions.reorder(capture_time: :asc).first
  end

  def previous(different: false)
    query = page.versions.where('capture_time < ?', capture_time)
    query = query.where(different: true) if different
    query.first
  end

  def next(different: false)
    query = page.versions.where('capture_time > ?', capture_time)
    query = query.where(different: true) if different
    query.last
  end

  def change_from_previous(different: false)
    Change.between(from: previous(different:), to: self, create: nil)
  end

  def change_from_next(different: false)
    Change.between(from: self, to: self.next(different:), create: nil)
  end

  def change_from_earliest
    Change.between(from: earliest, to: self, create: nil)
  end

  def ensure_change_from_previous(different: false)
    Change.between(from: previous(different:), to: self, create: :new)
  end

  def ensure_change_from_next(different: false)
    Change.between(from: self, to: self.next(different:), create: :new)
  end

  def ensure_change_from_earliest
    Change.between(from: earliest, to: self, create: :new)
  end

  def update_different_attribute(save: true)
    previous = self.previous
    self.different = previous.nil? || previous.body_hash != body_hash
    save! if save

    # NOTE: it would be nice to stop early here if we didn't make any changes,
    # but `different` defaults to `true` so if we just inserted this version
    # and it was different, we won't have "changed" the attribute, even though
    # we still need to update the next (because this was inserted before it).
    last_hash = body_hash
    following = page.versions
      .where('capture_time > ?', capture_time)
      .reorder(capture_time: :asc)

    following.each do |next_version|
      new_different = last_hash != next_version.body_hash
      if next_version.different? == new_different
        break
      else
        next_version.update!(different: new_different)
        last_hash = next_version.body_hash
      end
    end
  end

  def media_type=(value)
    value = normalize_media_type(value) if value.present?
    super
  end

  # TODO: Consider falling back to sniffing the content at `body_url`?
  def derive_media_type(force: false, value: nil)
    return if media_type && !force

    response_headers = headers
    meta = source_metadata
    content_type = value ||
                   response_headers['content-type'] ||
                   meta['content_type'] ||
                   meta['media_type'] ||
                   meta['media'] ||
                   meta['mime_type']
    return unless content_type

    media = parse_media_type(content_type)
    self.media_type = media if media
  end

  def derive_content_length
    return if content_length

    length = headers['content-length']&.to_i
    self.content_length = length if length
  end

  def effective_status # rubocop:disable Metrics/PerceivedComplexity
    return 404 if network_error.present?

    # Special case for 'greet.anl.gov', which seems to occasionally respond
    # with a 500 status code even though it's definitely OK content.
    # We've never seen a real 500 error there, so this is based on what we've
    # seen with 404 errors.
    return 200 if status == 500 && url&.include?('greet.anl.gov/') && !title&.include?('500')

    # Otherwise we expect error statuses to really be errors.
    return status if status.present? && status >= 400

    # Some pages redirect to a non-4xx response when they are removed.
    redirected_to = redirects.last
    if redirected_to
      surt_url = Surt.surt(url)
      surt_destination = Surt.surt(redirected_to)

      if surt_url != surt_destination
        original_host, original_path = surt_url.split(')', 2)
        redirect_host, redirect_path = surt_destination.split(')', 2)

        # Special case for the EPA "signpost" page, where they redirected hundreds
        # of climate-related pages to instead of giving them 4xx status codes.
        return 404 if surt_destination == 'gov,epa)/sites/production/files/signpost/cc.html'

        # Special case for climate.nasa.gov getting moved with bad redirects for all the sub-pages.
        return 404 if original_host == 'gov,nasa,climate' &&
                      surt_destination == 'gov,nasa,science)/climate-change'

        return 429 if surt_destination == 'gov,federalregister,unblock)/'

        # We see a lot of redirects to the root of the same domain when a page is removed.
        return 404 if redirect_host == original_host &&
                      !home_path?(original_path) &&
                      home_path?(redirect_path)
      end
    end

    # Simple heuristics to determine whether a page with an OK status code
    # actually represents an error.
    if title.present?
      # Page titles are frequently formulated like "<title> | <site name>" or
      # "<title> | <site section> | <site name>" (order may also be reversed).
      # It's helpful to split up the sections and evaluate each independently.
      title.downcase.split(/\s+(?:-+|\|)\s+/).each do |t|
        t = t.strip

        # We frequently see page titles that are just the code and the literal
        # message from the standard, e.g. "501 Not Implemented".
        return t.to_i if STANDARD_STATUS_MESSAGES.include?(t)

        # If the string is just "DDD", "error DDD", or "DDD error" and DDD
        # starts with a 4 or 5, this is almost certainly just a status code.
        code_match = /^(?:error )?(4\d\d|5\d\d)(?: error)?$/.match(t)
        return code_match[1].to_i if code_match.present?

        # Other more special messages we've seen.
        return 404 if /\b(page|file)( was)? not found\b/.match?(t)
        return 404 if /\bthis page isn['’]t available\b/.match?(t)
        return 403 if /\baccess denied\b/.match?(t)
        return 403 if /\brestricted access\b/.match?(t)
        return 500 if t == 'error'
        return 500 if t.include?('error processing ssi file')
        return 500 if t.include?('error occurred')
        return 500 if /\b(unexpected|server) error\b/.match?(t)
        return 503 if /\bsite under maintenance\b/.match?(t)
      end
    end

    # Oracle APEX includes this header on errors. It's ambiguous about the
    # kind of error, so only check this if the other heuristics didn't work.
    return 500 if headers.fetch('apex-debug-id', '').downcase.include?('level=error')

    status || 200
  end

  def status_ok?(strict: false)
    if strict
      status < 400
    else
      effective_status < 400
    end
  end

  def domain
    url.present? ? Addressable::URI.parse(url).host : '<unknown>'
  end

  def redirects
    urls = source_metadata['redirects'].dup || []
    unless urls.is_a?(Array)
      message = "Invalid `source_metadata.redirects` for version #{uuid}"
      Rails.logger.error(message)
      Sentry.capture_message(message, level: :error)
      urls = []
    end

    # TODO: add option to fetch raw body and look for client redirects? FWIW, data from the EDGI crawler already
    #  includes these.

    urls.shift if urls.first == url
    urls
  end

  # KEEP IN SYNC WITH estimate_snapshot_quality IN web-monitoring-processing!
  # These two routines are meant to be equivalent. Ideally we need this code
  # to be shared, but for now, make sure to copy any changes you make here
  # to that repo and vice-versa.
  def estimate_quality! # rubocop:disable Metrics/AbcSize, Metrics/PerceivedComplexity
    # Some ancient Versionista and PageFreezer data does not have status codes.
    status = self.status || (network_error.present? ? 600 : 200)

    # TODO: unify with derive_content_length, or drop this?
    content_length = self.content_length || headers.fetch('content-length', '-1').to_i
    status = 500 if status == 200 && content_length == 0
    server = headers.fetch('server', '').downcase

    no_cache = false
    if headers.key?('cache-control')
      cache_control = headers['cache-control'].downcase
      no_cache = cache_control.include?('no-cache') || cache_control.include?('max-age=0')
    end
    if !no_cache && headers.key?('expires')
      begin
        no_cache = Integer(headers['expires']) < 60
      rescue ArgumentError
        expires = Time.zone.parse(headers['expires']) || capture_time
        request_time = (headers.key?('date') && Time.zone.parse(headers['date'])) || capture_time
        no_cache = (expires - request_time) < 60
      end
    end

    x_cache = headers.fetch('x-cache', '').downcase
    cache_error = x_cache.include?('error') || x_cache.include?('n/a')

    is_short_or_unknown = content_length < 1000
    content_type = media_type.presence || headers.fetch('content-type', '')
    is_html = content_type.starts_with?('text/html')

    # AWS WAF sends the `x-amzn-waf-action` header for a lot of blocking
    # actions. It can come from different servers, so should be handled on its
    # own as a clear, concrete signal.
    waf_action = headers.fetch('x-amzn-waf-action', '').downcase
    if waf_action.present?
      if ['challenge', 'captcha'].include?(waf_action)
        return 0.0
      else
        Rails.logger.warn("Unknown value for x-amzn-waf-action header: '#{waf_action}'")
      end
    end

    cf_mitigated = headers.fetch('cf-mitigated', '').downcase
    if cf_mitigated.present?
      if server == 'cloudflare'
        if cf_mitigated == 'challenge'
          return 0.0
        else
          Rails.logger.warn("Unknown value for cf-mitigated header: '#{cf_mitigated}'")
        end
      else
        # We expect cf-mitigated to always come alongside a server header
        # for Cloudflare, unlike with AWS WAF above.
        Rails.logger.warn("Unknown `server` for cf-mitigated header: 'server: #{server}' 'cf-mitigated: #{cf_mitigated}' (expected 'server: cloudflare')")
      end
    end

    if status >= 400 && server.starts_with?('awselb/')
      # We assume that blocking-related status code coming from directly from
      # an AWS ELB and not the origin server is really blocking.
      if status == 429
        return 0.0
      elsif status == 403 && is_short_or_unknown
        return 0.1
      # Keeping these more fuzzy rules for other errors (e.g. 502/503/504
      # gateway errors) that are more iffy (a gateway error could be
      # intermittent, or it could be that the underlying origin server was
      # shut down) separate from the more concrete ones above. We probably
      # wouldn't want to fail to *record* these when importing even though we
      # want to treat them as suspect for task sheets.
      elsif is_short_or_unknown && is_html
        return 0.5
      end
    elsif status >= 400 && server == 'akamaighost' && is_short_or_unknown && no_cache
      return 0.0
    elsif server == 'cloudfront'
      # We're pretty confident CloudFront will never return a 404 as part of
      # its own WAF (it will return a 403). 404s only come from the origin.
      # Still... this is low confidence.
      return 0.0 if cache_error && status >= 400 && status != 404
    # elsif server == 'cloudflare'
    #     # We don't have any special hints for Cloudlare beyond the cf-mitigated
    #     # header, which is already handled above.
    #     # NOTES: When Cloudflare provides `server-timing`, it will identify its
    #     # time with `cfEdge` and origin time with `cfOrigin`. Having edge time
    #     # but no record of origin time may also be a good hint of WAF behavior.
    #     ...
    elsif status >= 400 && status < 500 && server.blank? && is_short_or_unknown
      # Very lazy server-timing header parsing. We could parse out the
      # description and the duration, but those don't matter too much here.
      server_timing = headers.fetch('server-timing', '').split(',').each_with_object({}) do |item, result|
        key, value = item.split(';', 2)
        result[key.downcase.strip] = value.strip
      end

      # Akamai Edgesuite doesn't explicitly identify itself, but it seems to
      # always include recognizable server-timing features and a 4xx status.
      #
      # Example good capture:
      #   server-timing: cdn-cache; desc=MISS, edge; dur=22, origin; dur=369, ak_p; desc="1776475897753_386075716_3264768070_38998_7536_11_0_255";dur=1
      #
      # Example bad capture:
      #   server-timing: cdn-cache; desc=HIT, edge; dur=1, ak_p; desc="1775872487192_399532111_2052555389_12_6012_263_573_-";dur=1
      #
      # (Unfortunately, can't find any examples of good cache hits.)
      if server_timing.key?('ak_p')
         && server_timing.key?('cdn-cache')
         # Expect no origin info (since WAF will have never hit the origin)
         # and single-digit milliseconds at the edge.
         && !server_timing.key?('origin')
         && /(^|;)\s*dur=\d+(\.|$)/.match?(server_timing.fetch('edge', ''))
        return 0.25
      end
    # TODO: see if we have any Azure CDN examples?
    elsif status == 429 && is_short_or_unknown
      return 0.1
    end
    # TODO: More general heuristics?
    # else:
    #     content_type = media_type or headers.get('content-type', '')
    #     x_cache = headers.get('x-cache', '').lower()
    #     cache_miss = x_cache and not x_cache.startswith('hit')
    #     return content_type.startswith('text/html') and is_short_or_unknown and cache_miss

    # Special cases for redirects to known sinks that represent crawl blocking.
    if status == 200 && redirects.present?
      block_url = 'unblock.federalregister.gov/'
      if redirects.last.downcase.sub(/^https?:\/\//, '') == block_url && url.downcase.sub(/^https?:\/\//, '') != block_url
        return 0.0
      end
    end

    1.0
  end

  def estimate_quality
    estimate_quality!
  rescue StandardError => error
    Rails.logger.error(error)
    Sentry.capture_exception(error)
    1.0
  end

  def quality
    @quality ||= estimate_quality
  end

  def headers
    super || {}
  end

  def source_metadata
    super || {}
  end

  def sync_page_title
    page.update_page_title(capture_time)
  end

  private

  def normalize_media_type(text)
    normal = text.strip.downcase
    MEDIA_TYPE_SYNONYMS[normal] || normal
  end

  def parse_media_type(text)
    media = text.split(';', 2)[0]
    return nil unless media.present? && media.match?(MEDIA_TYPE_PATTERN)

    normalize_media_type(media)
  end

  def home_path?(path)
    path.match?(/^\/((index|home)(\.\w+)?)?$/)
  end
end
