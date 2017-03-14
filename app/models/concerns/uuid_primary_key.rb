module UuidPrimaryKey
  extend ActiveSupport::Concern

  included do
    self.primary_key = 'uuid'
    before_create :generate_uuid
  end

  protected

  def generate_uuid
    if self.uuid.blank?
      self.uuid = SecureRandom.uuid
    end
  end
end
