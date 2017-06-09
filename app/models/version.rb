class Version < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :page, foreign_key: :page_uuid, required: true, inverse_of: :versions, touch: true
  has_many :tracked_changes, class_name: 'Change', foreign_key: 'uuid_to'
  has_many :invalid_changes,
    ->(version) { where.not(uuid_from: version.previous.uuid) },
    class_name: 'Change',
    foreign_key: 'uuid_to'

  def previous
    self.page.versions.where('capture_time < ?', self.capture_time).first
  end

  def change_from_previous
    Change.between(from: previous, to: self)
  end

  def current_annotation
    change = self.change_from_previous
    change && change.current_annotation
  end

  def annotations
    change = self.change_from_previous
    change ? change.annotations : []
  end
end
