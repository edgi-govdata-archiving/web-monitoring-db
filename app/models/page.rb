class Page < ApplicationRecord
  include UuidPrimaryKey
  include Taggable
  include SimpleTitle

  # TODO: pull these from environment variables
  # Timeframe over which to calculate a page's status code. Because a single
  # version could be an intermittent failure, we don't just use the latest
  # version's status, but instead look at all the versions of the past N days.
  STATUS_TIMEFRAME = 14.days
  # What percentage (between 0 and 1) of versions must have a successful
  # status code for the page's status to be `200`.
  STATUS_SUCCESS_THRESHOLD = 0.75

  has_many :versions,
           -> { order(capture_time: :desc) },
           foreign_key: 'page_uuid',
           inverse_of: :page
  has_one :earliest,
          (lambda do
            # DISTINCT ON requires the first ORDER to be the distinct column(s)
            relation = order('versions.page_uuid')
            # HACK: This is not public API, but I couldn't find a better way. The
            # `DISTINCT ON` statement has to be at the start of the WHERE clause, but
            # all public methods append to the end.
            relation.select_values = ['DISTINCT ON (versions.page_uuid) versions.*']
            relation.order('versions.capture_time ASC')
          end),
          foreign_key: 'page_uuid',
          class_name: 'Version'
  has_one :latest,
          (lambda do
            # DISTINCT ON requires the first ORDER to be the distinct column(s)
            relation = order('versions.page_uuid')
            # HACK: This is not public API, but I couldn't find a better way. The
            # `DISTINCT ON` statement has to be at the start of the WHERE clause, but
            # all public methods append to the end.
            relation.select_values = ['DISTINCT ON (versions.page_uuid) versions.*']
            relation.order('versions.capture_time DESC').where(different: true)
          end),
          foreign_key: 'page_uuid',
          class_name: 'Version'
  # This needs a funky name because `changes` is a an activerecord method
  has_many :tracked_changes, through: :versions

  has_many :maintainerships, foreign_key: :page_uuid
  has_many :maintainers, through: :maintainerships

  before_create :ensure_url_key
  after_create :ensure_domain_and_news_tags
  before_save :normalize_url
  validate :url_must_have_domain
  validates :status,
            allow_nil: true,
            inclusion: { in: 100...600, message: 'is not between 100 and 599' }

  def self.find_by_url(raw_url)
    url = normalize_url(raw_url)
    Page.find_by(url: url) || Page.find_by(url_key: create_url_key(url))
  end

  def self.normalize_url(url)
    return if url.nil?

    if url.match?(/^[\w\+\-\.]+:\/\//)
      url
    else
      "http://#{url}"
    end
  end

  def self.create_url_key(url)
    Surt.surt(url)
  end

  def add_maintainer(maintainer)
    unless maintainer.is_a?(Maintainer)
      maintainer = Maintainer.find_or_create_by(name: maintainer)
    end

    maintainers.push(maintainer) unless maintainers.include?(maintainer)
    maintainer
  end

  def remove_maintainer(maintainer)
    attached_maintainer =
      if maintainer.is_a?(Maintainer)
        maintainers.find_by(uuid: maintainer.uuid)
      else
        maintainers.find_by(name: maintainer.strip)
      end
    maintainers.delete(attached_maintainer) if attached_maintainer
  end

  def as_json(options = {})
    # Tags and Maintainers get a special JSON representation
    custom_options = options.clone
    includes = custom_options[:include]
    associations = { maintainers: false, tags: false }

    if [:maintainers, :tags].include?(includes)
      associations[includes] = true
      custom_options.delete(:include)
    elsif includes.is_a?(Enumerable)
      custom_options[:include] = includes.clone
      if custom_options[:include].delete(:maintainers)
        associations[:maintainers] = true
      end
      if custom_options[:include].delete(:tags)
        associations[:tags] = true
      end
    end

    result = super.as_json(custom_options)

    if associations[:maintainers]
      result['maintainers'] = self.maintainerships.as_json
    end

    if associations[:tags]
      result['tags'] = self.taggings.as_json
    end

    result
  end

  def update_url_key
    update(url_key: Page.create_url_key(url))
  end

  def ensure_domain_and_news_tags
    self.add_tag("domain:#{domain}")
    self.add_tag("2l-domain:#{second_level_domain}")
    self.add_tag('news') if news?
  end

  def update_status
    new_status = calculate_status
    self.update(status: new_status) unless new_status.zero?
    self.status
  end

  protected

  def news?
    url.include?('/news') || url.include?('/blog') || url.include?('/press')
  end

  def ensure_url_key
    self.url_key ||= Page.create_url_key(url)
  end

  def normalize_url
    self.url = self.class.normalize_url(self.url)
  end

  def domain
    url.match(/^([\w\+\-\.]+:\/\/)?([^\/]+\.[^\/]{2,})/).try(:[], 2)
  end

  def second_level_domain
    full_domain = domain
    full_domain && full_domain.split('.')[-2..-1].join('.')
  end

  def url_must_have_domain
    unless domain.present?
      errors.add(:url, 'must have a domain')
    end
  end

  # Calculate the effective HTTP status code for this page. Because the
  # occasional failure might happen when capturing a version, we don't
  # just take the latest status. Instead, we only treat failures as real
  # if they account for a certain percentage of the last N days.
  def calculate_status(relative_to: nil)
    now = relative_to || Time.now
    start_time = now - STATUS_TIMEFRAME
    latest_with_status = versions
      .where('status IS NOT NULL')
      .order(capture_time: :desc).first

    # Bail out if we have no versions with a status!
    return 0 unless latest_with_status

    if latest_with_status.status < 400 || latest_with_status.capture_time < start_time
      return latest_with_status.status
    end

    success_time = 0.seconds
    total_time = 0.seconds
    last_time = now
    last_error = 0
    candidates = versions
      .where('status IS NOT NULL')
      .where('capture_time >= ?', start_time)
      .order(capture_time: :desc)
    candidates.each do |version|
      version_time = last_time - version.capture_time
      total_time += version_time
      if version.status < 400
        success_time += version_time
      elsif last_error == 0
        last_error = version.status
      end
      last_time = version.capture_time
    end

    base_version = versions
      .where('status IS NOT NULL')
      .where('capture_time < ?', start_time)
      .order(capture_time: :desc).first
    if base_version
      version_time = last_time - start_time
      total_time += version_time
      if base_version.status < 400
        success_time += version_time
      elsif last_error == 0
        last_error = base_version.status
      end
    end

    # Bail out if we didn't actually cover any meaningful timeframe.
    return 0 if total_time == 0

    success_rate = success_time.to_f / total_time
    success_rate < STATUS_SUCCESS_THRESHOLD ? last_error : 200
  end
end
