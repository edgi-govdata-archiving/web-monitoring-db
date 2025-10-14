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
    point = [point[field], point[self.primary_key]].compact if point.is_a?(Version)

    raise Api::InputError, 'Invalid query sorting point' if point && point.length != 2
    # Only allow fields where there is an index on `(field, uuid)`.
    unless [:capture_time, :created_at].include?(field)
      raise Api::InputError, 'Versions can only be sorted by `capture_time` or `created_at`'
    end

    query = self.reorder({ field => direction, uuid: direction })
    if point
      fields = [field, self.primary_key].collect {|f| "#{self.table_name}.#{f}"}
      comparator = direction == :asc ? '>' : '<'
      query.where("(#{fields.join(',')}) #{comparator} (?, ?)", *point)
    else
      query
    end
  end

  def earliest
    self.page.versions.reorder(capture_time: :asc).first
  end

  def previous(different: false)
    query = self.page.versions.where('capture_time < ?', self.capture_time)
    query = query.where(different: true) if different
    query.first
  end

  def next(different: false)
    query = self.page.versions.where('capture_time > ?', self.capture_time)
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
    self.save! if save

    # NOTE: it would be nice to stop early here if we didn't make any changes,
    # but `different` defaults to `true` so if we just inserted this version
    # and it was different, we won't have "changed" the attribute, even though
    # we still need to update the next (because this was inserted before it).
    last_hash = body_hash
    following = page.versions
      .where('capture_time > ?', self.capture_time)
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
    return if self.media_type && !force

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
    return if self.content_length

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
      # Special case for the EPA "signpost" page, where they redirected hundreds
      # of climate-related pages to instead of giving them 4xx status codes.
      return 404 if redirected_to.ends_with?('epa.gov/sites/production/files/signpost/cc.html')

      # Special case for climate.nasa.gov getting moved with bad redirects for all the sub-pages.
      return 404 if (
        /^https?:\/\/climate.nasa.gov\/.+$/i.match?(url) &&
        redirected_to.ends_with?('://science.nasa.gov/climate-change/')
      )

      # We see a lot of redirects to the root of the same domain when a page is removed.
      parsed_url = Addressable::URI.parse(url)
      return 404 if parsed_url.path != '/' && Surt.surt(parsed_url.join('/')) == Surt.surt(redirected_to)
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
    urls = source_metadata['redirects'] || []
    raise TypeError, "Unknown type for source_metadata.redirects on version: #{uuid}" unless urls.is_a?(Array)

    # TODO: add option to fetch raw body and look for client redirects? FWIW, data from the EDGI crawler already
    #  includes these.

    urls.shift if urls.first == url
    urls
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
end
