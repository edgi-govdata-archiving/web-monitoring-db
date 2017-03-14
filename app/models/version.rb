class Version < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :page, foreign_key: :page_uuid, required: true, inverse_of: :versions
  has_many :tracked_changes, class_name: 'Change', foreign_key: 'uuid_to'

  def previous
    self.page.versions.where('capture_time < ?', self.capture_time).first
  end

  def change_from_previous
    Change.between(to: self)
  end
end
