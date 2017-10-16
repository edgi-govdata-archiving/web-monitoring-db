class Version < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :page, foreign_key: :page_uuid, required: true, inverse_of: :versions, touch: true
  has_many :tracked_changes, class_name: 'Change', foreign_key: 'uuid_to'
  has_many :invalid_changes,
    ->(version) { where.not(uuid_from: version.previous.uuid) },
    class_name: 'Change',
    foreign_key: 'uuid_to'

  after_create :sync_page_title

  def previous
    self.page.versions.where('capture_time < ?', self.capture_time).first
  end

  def next
    self.page.versions.where('capture_time > ?', self.capture_time).last
  end

  def change_from_previous
    Change.between(from: previous, to: self)
  end

  private

  def sync_page_title
    if title.present?
      most_recent_capture_time = page.latest.capture_time
      page.update(title: title) if most_recent_capture_time.nil? || most_recent_capture_time <= capture_time
    end
  end
end
