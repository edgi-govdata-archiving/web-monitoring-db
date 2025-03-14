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
           inverse_of: :page,
           # You must explcitly dissociate or move versions before destroying.
           # It's OK for a version to be orphaned from all pages, but we want
           # to make sure that's an intentional action and not accidental.
           dependent: :restrict_with_error
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
           dependent: :delete_all
  has_many :current_urls,
           -> { current },
           class_name: 'PageUrl',
           foreign_key: 'page_uuid'

  has_many :maintainerships, foreign_key: :page_uuid, dependent: :delete_all
  has_many :maintainers, through: :maintainerships, dependent: nil

  scope(:needing_status_update, lambda do
    # NOTE: pages.status can be NULL, so use DISTINCT FROM instead of <>/!= to compare.
    joins(:versions)
      .where('versions.capture_time >= ?', (STATUS_TIMEFRAME * STATUS_SUCCESS_THRESHOLD).ago)
      .where('versions.status IS DISTINCT FROM pages.status')
  end)

  normalizes :url, with: ->(url) { PageUrl.normalize_url(url) }
  after_create :ensure_domain_and_news_tags
  before_save :derive_url_key
  after_save :ensure_page_urls
  validate :url_must_have_domain
  validates :status,
            allow_nil: true,
            inclusion: { in: 100...600, message: 'is not between 100 and 599' }

  def self.find_by_url(url, at_time: nil)
    current = PageUrl.eager_load(:page).current(at_time)
    found = current.find_by(url:)
    return found.page if found

    key = PageUrl.create_url_key(url)
    found = current.find_by(url_key: key)
    return found.page if found

    with_pages = PageUrl.eager_load(:page).order(to_time: :desc)
    found = with_pages.find_by(url:) ||
            with_pages.find_by(url_key: key)
    return found.page if found

    # TODO: remove this fallback when data is migrated over to Page.urls.
    Page.find_by(url:) || Page.find_by(url_key: key)
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
    custom_options = options.dup
    includes = custom_options[:include]
    associations = { maintainers: false, tags: false }

    if [:maintainers, :tags].include?(includes)
      associations[includes] = true
      custom_options.delete(:include)
    elsif includes.is_a?(Enumerable)
      custom_options[:include] = includes.dup
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
    urls.find_or_create_by!(url:) if saved_change_to_attribute?('url')
  end

  def update_status(relative_to: nil)
    new_status = calculate_status(relative_to:)
    self.update(status: new_status) unless new_status.zero?
    self.status
  end

  def merge(*other_pages)
    Page.transaction do
      first_version_time = nil
      other_pages.each do |other|
        audit_data = other.create_audit_record

        # Move versions from other page.
        other.versions.to_a.each do |version|
          self.versions << version
          if first_version_time.nil? || first_version_time > version.capture_time
            first_version_time = version.capture_time
          end
        end
        # The above doesn't update the source page's `versions`, so reload.
        other.versions.reload

        # Copy other attributes from other page.
        other.tags.each {|tag| add_tag(tag)}
        other.maintainers.each {|maintainer| add_maintainer(maintainer)}
        other.urls.each do |page_url|
          # TODO: it would be slightly nicer to collapse/merge PageUrls with
          # overlapping or intersecting time ranges here.
          # NOTE: we have to be careful not to trip the DB's uniqueness
          # constraints here or we hose the transaction.
          just_created = false
          merged_url = urls.find_or_create_by(
            url: page_url.url,
            from_time: page_url.from_time,
            to_time: page_url.to_time
          ) do |new_url|
            new_url.notes = page_url.notes
            just_created = true
          end

          unless just_created
            new_notes = [merged_url.notes, page_url.notes].compact.join(' ')
            merged_url.update(notes: new_notes)
          end
        end

        # Keep a record so we can redirect requests for the merged page.
        # Delete the actual page record rather than keep it around so we don't
        # have to worry about messy partial indexes and querying around URLs.
        MergedPage.create!(uuid: other.uuid, target: self, audit_data:)
        # If the page we're removing was previously a merge target, update
        # its references.
        MergedPage.where(target_uuid: other.uuid).update_all(target_uuid: self.uuid)
        # And finally drop the merged page.
        other.destroy!

        audit_json = Oj.dump(audit_data, mode: :rails)
        Rails.logger.info("Merged page #{other.uuid} into #{uuid}. Old data: #{audit_json}")
      end

      # Recalculate denormalized attributes
      update_page_title(first_version_time)
      update_versions_different(first_version_time)
      # TODO: it might be neat to clean up overlapping URL timeframes
    end
  end

  def update_page_title(from_time = nil)
    candidates = versions.reorder(capture_time: :desc)
    candidates = candidates.where('capture_time >= ?', from_time) if from_time

    new_title = nil
    candidates.each do |version|
      if version.title.present? && version.status_ok?
        new_title = version.title
        break
      end
    end

    # Fall back to the filename from the page's URL.
    if new_title.blank? && title.blank?
      filename = /\/([^\/]+)\/?$/.match(url).try(:[], 1)
      new_title = CGI.unescape(filename || '')
    end


    self.update(title: new_title) if new_title.present?
    new_title
  end

  protected

  def news?
    url.include?('/news') || url.include?('/blog') || url.include?('/press')
  end

  def derive_url_key
    self.url_key = PageUrl.create_url_key(url) if url_key.nil? || url_changed?
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

    status_query = versions.where('status IS NOT NULL OR network_error IS NOT NULL').order(capture_time: :desc)
    candidates = status_query.where('capture_time >= ?', start_time).to_a
    base_version = status_query.where('capture_time < ?', start_time).first
    candidates << base_version if base_version

    candidates.each do |version|
      # We only want to consider the part of our timeframe that the version covers
      capture_time = [version.capture_time, start_time].max
      version_time = last_time - capture_time
      total_time += version_time

      version_status = version.effective_status
      if version_status >= 400
        error_time += version_time
        latest_error ||= version_status
      end
      last_time = version.capture_time
    end

    return 0 if total_time == 0

    success_rate = 1 - (error_time.to_f / total_time)
    success_rate < STATUS_SUCCESS_THRESHOLD ? latest_error : 200
  end

  # TODO: figure out whether there's a reasonable way to merge this logic with
  # `Version#update_different_attribute`.
  def update_versions_different(from_time)
    previous_hash = nil
    candidates = versions
      .where('capture_time >= ?', from_time)
      .reorder(capture_time: :asc)

    candidates.each do |version|
      if previous_hash.nil?
        previous_hash = version.previous(different: false).try(:body_hash)
      end

      version.update(different: version.body_hash != previous_hash)
      previous_hash = version.body_hash
    end
  end

  # Creates a hash representing the current state of a page. Used for logging
  # and other audit related purposes when deleting/merging pages.
  def create_audit_record
    # URLs are entirely unique to the page, so have to be recorded
    # completely rather than referenced by ID.
    urls_data = urls.collect do |page_url|
      page_url.attributes.slice('url', 'from_time', 'to_time', 'notes')
    end

    attributes.merge({
      'tags' => tags.collect(&:name),
      'maintainers' => maintainers.collect(&:name),
      'versions' => versions.collect(&:uuid),
      'urls' => urls_data
    })
  end
end
