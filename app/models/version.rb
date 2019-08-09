class Version < ApplicationRecord
  include UuidPrimaryKey
  include SimpleTitle

  belongs_to :page, foreign_key: :page_uuid, required: true, inverse_of: :versions, touch: true
  has_many :tracked_changes, class_name: 'Change', foreign_key: 'uuid_to'
  has_many :invalid_changes,
           ->(version) { where.not(uuid_from: version.previous.uuid) },
           class_name: 'Change',
           foreign_key: 'uuid_to'

  after_create :sync_page_title
  validates :status,
            allow_nil: true,
            inclusion: { in: 100...600, message: 'is not between 100 and 599' }

  def earliest
    self.page.versions.reorder(capture_time: :asc).first
  end

  def previous(different: true)
    self.page.versions
      .where('capture_time < ?', self.capture_time)
      .where(different: different)
      .first
  end

  def next(different: true)
    self.page.versions
      .where('capture_time > ?', self.capture_time)
      .where(different: different)
      .last
  end

  def change_from_previous(different: true)
    Change.between(from: previous(different: different), to: self, create: nil)
  end

  def change_from_next(different: true)
    Change.between(from: self, to: self.next(different: different), create: nil)
  end

  def change_from_earliest
    Change.between(from: earliest, to: self, create: nil)
  end

  def ensure_change_from_previous(different: true)
    Change.between(from: previous(different: different), to: self, create: :new)
  end

  def ensure_change_from_next(different: true)
    Change.between(from: self, to: self.next(different: different), create: :new)
  end

  def ensure_change_from_earliest
    Change.between(from: earliest, to: self, create: :new)
  end

  def update_different_attribute(save: true)
    previous = self.previous
    self.different = previous.nil? || previous.version_hash != version_hash
    self.save if save

    if self.different?
      following = page.versions
        .where('capture_time > ?', self.capture_time)
        .reorder(capture_time: :asc)

      following.each do |next_version|
        new_different = version_hash != next_version.version_hash
        if next_version.different? == new_different
          break
        else
          next_version.different = new_different
          next_version.save!
        end
      end
    end
  end

  private

  def sync_page_title
    if title.present?
      most_recent_capture_time = page.latest.capture_time
      page.update(title: title) if most_recent_capture_time.nil? || most_recent_capture_time <= capture_time
    end
  end
end
