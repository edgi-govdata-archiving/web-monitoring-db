class Page < ApplicationRecord
  include UuidPrimaryKey

  has_many :versions, -> { order(capture_time: :desc) }, foreign_key: 'page_uuid', inverse_of: :page
  has_one :latest, (lambda do
    relation = order('versions.page_uuid')
    relation.select_values = ['DISTINCT ON (versions.page_uuid) versions.*']
    relation.order('versions.capture_time DESC')
  end), foreign_key: 'page_uuid', class_name: 'Version'

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
