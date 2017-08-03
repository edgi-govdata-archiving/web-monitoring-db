class Import < ApplicationRecord
  belongs_to :user
  enum status: [:pending, :processing, :complete]
  enum update_behavior: [:skip, :replace, :merge], _suffix: :existing_records
  validates :file, presence: true
  after_initialize :ensure_processing_errors

  def self.create_with_data(attributes, data)
    create(attributes.merge(file: create_data_file(data)))
  end

  def self.create_data_file(data)
    file_key = SecureRandom.uuid
    FileStorage.default.save_file(file_key, data)
    file_key
  end

  def load_data
    FileStorage.default.get_file(file)
  end

  protected

  def ensure_processing_errors
    self.processing_errors ||= []
  end
end
