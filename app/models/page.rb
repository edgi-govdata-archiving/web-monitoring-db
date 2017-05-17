class Page < ApplicationRecord
  include UuidPrimaryKey

  has_many :versions, -> { order(capture_time: :desc) }, foreign_key: 'page_uuid', inverse_of: :page

  before_save :normalize_url
  validate :url_must_have_domain

  def self.normalize_url(url)
    return if url.nil?
    if url.match?(/^[\w\+\-\.]+:\/\//)
      url
    else
      "http://#{url}"
    end
  end

  # A serialized page should always include some version info. If expanded
  # version objects weren't requested, it includes the latest version.
  def as_json(*args)
    result = super(*args)
    if result['versions'].nil?
      result['latest'] = self.versions.first.as_json
    end
    result
  end

  protected

  def normalize_url
    self.url = self.class.normalize_url(self.url)
  end

  def url_must_have_domain
    unless url.match?(/^([\w\+\-\.]+:\/\/)?[^\/]+\.[^\/]{2,}/)
      errors.add(:url, 'must have a domain')
    end
  end
end
