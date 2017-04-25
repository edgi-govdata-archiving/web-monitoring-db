class Page < ApplicationRecord
  include UuidPrimaryKey

  has_many :versions, -> { order(created_at: :desc) }, foreign_key: 'page_uuid', inverse_of: :page

  # A serialized page should always include some version info. If expanded
  # version objects weren't requested, it includes the latest version.
  def as_json(*args)
    result = super(*args)
    if result['versions'].nil?
      result['latest'] = self.versions.first.as_json
    end
    result
  end
end
