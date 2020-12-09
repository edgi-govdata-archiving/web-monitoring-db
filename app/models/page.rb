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
  has_many :urls,
           class_name: 'PageUrl',
           foreign_key: 'page_uuid',
           inverse_of: :page,
           dependent: :destroy
  has_many :current_urls,
           -> { current },
           class_name: 'PageUrl',
           foreign_key: 'page_uuid'

  has_many :maintainerships, foreign_key: :page_uuid
  has_many :maintainers, through: :maintainerships

  scope(:needing_status_update, lambda do
    # NOTE: pages.status can be NULL, so use DISTINCT FROM instead of <>/!= to compare.
    joins(:versions)
      .where('versions.capture_time >= ?', (STATUS_TIMEFRAME * STATUS_SUCCESS_THRESHOLD).ago)
      .where('versions.status IS DISTINCT FROM pages.status')
  end)

  before_create :ensure_url_key
  after_create :ensure_domain_and_news_tags
  before_save :normalize_url
  after_save :ensure_page_urls
  validate :url_must_have_domain
  validates :status,
            allow_nil: true,
            inclusion: { in: 100...600, message: 'is not between 100 and 599' }

  def self.find_by_url(raw_url)
    url = normalize_url(raw_url)

    with_urls = Page.includes(:current_urls)
    found = with_urls.find_by(page_urls: { url: url })
    return found if found

    key = PageUrl.create_url_key(url)
    found = with_urls.find_by(page_urls: { url_key: key })
    return found if found

    with_urls = Page.includes(:urls).order('page_urls.to_time DESC')
    found = with_urls.find_by(page_urls: { url: url }) ||
            with_urls.find_by(page_urls: { url_key: key })
    return found if found

    # TODO: remove this fallback when data is migrated over to Page.urls.
    Page.find_by(url: url) || Page.find_by(url_key: key)
  end

  def self.normalize_url(url)
    return if url.nil?

    if url.match?(/^[\w+\-.]+:\/\//)
      url
    else
      "http://#{url}"
    end
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
    update(url_key: PageUrl.create_url_key(url))
  end

  def ensure_domain_and_news_tags
    self.add_tag("domain:#{domain}")
    self.add_tag("2l-domain:#{second_level_domain}")
    self.add_tag('news') if news?
  end

  # Keep page creation relatively simple by automatically creating a PageUrl
  # for the page's current URL when creating a page. (Page#url is the current
  # canonical Url of the page, the true list of URLs associated with the page
  # should always be the list of PageUrls in Page#urls).
  def ensure_page_urls
    urls.find_or_create_by(url: url) if saved_change_to_attribute?('url')
  end

  def update_status
    new_status = calculate_status
    self.update(status: new_status) unless new_status.zero?
    self.status
  end

  def merge(*other_pages)
    earliest_version_time = nil
    other_pages.each do |other|
      # Move versions from other page.
      other.versions.each do |version|
        version.update(page_uuid: uuid)
        if earliest_version_time.nil? || earliest_version_time > version.capture_time
          earliest_version_time = version.capture_time
        end
      end

      # Copy other attributes from other page.
      other.tags.each {|tag| add_tag(tag)}
      other.maintainers.each {|maintainer| add_maintainer(maintainer)}
      other.urls.each do |page_url|
        begin
          page_url.update(page_uuid: self.uuid)
        rescue ActiveRecord::RecordNotUnique
          page_url.destroy
        end
      end

      # TODO: flag `other` as merged into this one so we can support old links
      other.update(active: false)
    end

    new_versions = self.versions.where('capture_time >= ?', earliest_version_time)

    # Recalculate title
    new_versions.reorder(capture_time: :desc).each do |version|
      break if version.sync_page_title
    end

    # Recalculate page.versions.different
    # TODO: figure out whether there's a reasonable way to merge this logic
    # with `Version#update_different_attribute`.
    previous_hash = nil
    new_versions.reorder(capture_time: :asc).each do |version|
      previous_hash = version.previous(different: false).try(:version_hash) if previous_hash.nil?
      version.update(different: version.version_hash != previous_hash)
      previous_hash = version.version_hash
    end

    # TODO: it might be neat to clean up overlapping URL timeframes
  end

  protected

  def news?
    url.include?('/news') || url.include?('/blog') || url.include?('/press')
  end

  def ensure_url_key
    self.url_key ||= PageUrl.create_url_key(url)
  end

  def normalize_url
    self.url = self.class.normalize_url(self.url)
  end

  def domain
    url.match(/^([\w+\-.]+:\/\/)?([^\/]+\.[^\/]{2,})/).try(:[], 2)
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
    last_time = now
    latest_error = nil
    total_time = 0.seconds
    error_time = 0.seconds

    status_query = versions.where('status IS NOT NULL').order(capture_time: :desc)
    candidates = status_query.where('capture_time >= ?', start_time).to_a
    base_version = status_query.where('capture_time < ?', start_time).first
    candidates << base_version if base_version

    candidates.each do |version|
      # We only want to consider the part of our timeframe that the version covers
      capture_time = [version.capture_time, start_time].max
      version_time = last_time - capture_time
      total_time += version_time

      if version.status >= 400
        error_time += version_time
        latest_error ||= version.status
      end
      last_time = version.capture_time
    end

    return 0 if total_time == 0

    success_rate = 1 - (error_time.to_f / total_time)
    success_rate < STATUS_SUCCESS_THRESHOLD ? latest_error : 200
  end
end
