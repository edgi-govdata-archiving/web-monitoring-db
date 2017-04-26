class Version < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :page, foreign_key: :page_uuid, required: true, inverse_of: :versions
  has_many :tracked_changes, class_name: 'Change', foreign_key: 'uuid_to'
  has_many :invalid_changes,
    ->(version) { where.not(uuid_from: version.previous.uuid) },
    class_name: 'Change',
    foreign_key: 'uuid_to'

  def previous
    self.page.versions.where('capture_time < ?', self.capture_time).first
  end

  def change_from_previous
    Change.between(to: self)
  end

  def current_annotation
    self.change_from_previous.current_annotation
  end

  def annotations
    self.change_from_previous.annotations
  end
end
