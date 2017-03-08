class VersionistaPage < ApplicationRecord
  has_many :versions, -> { order(created_at: :desc) }, class_name: 'VersionistaVersion', foreign_key: 'page_id', inverse_of: :page
end
