class Page < ApplicationRecord
  include UuidPrimaryKey
  include Taggable

  has_many :versions,
    -> { order(capture_time: :desc) },
    foreign_key: 'page_uuid',
    inverse_of: :page
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

  has_many :maintainerships, foreign_key: :page_uuid
  has_many :maintainers, through: :maintainerships

  before_create :ensure_url_key
  before_save :normalize_url
  validate :url_must_have_domain

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

  protected

  def ensure_url_key
    self.url_key ||= Page.create_url_key(url)
  end

  def normalize_url
    self.url = self.class.normalize_url(self.url)
  end

  def url_must_have_domain
    unless url.match?(/^([\w\+\-\.]+:\/\/)?[^\/]+\.[^\/]{2,}/)
      errors.add(:url, 'must have a domain')
    end
  end
end
