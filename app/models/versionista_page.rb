class VersionistaPage < ApplicationRecord
  has_many :versions, -> { order(created_at: :desc) }, class_name: 'VersionistaVersion', foreign_key: 'page_id', inverse_of: :page

  def as_json(*args)
    result = super(*args)
    if result['versions'].nil?
      result['latest'] = self.versions.first.as_json
    end
    result
  end
end
