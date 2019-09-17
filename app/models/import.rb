class Import < ApplicationRecord
  belongs_to :user
  enum status: [:pending, :processing, :complete]
  enum update_behavior: [:skip, :replace, :merge], _suffix: :existing_records
  validates :file, presence: true
  after_initialize :ensure_processing_errors_and_warnings
  before_save :persist_logs

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

  def load_logs
    return if log_file.blank?

    FileStorage.default.get_file(log_file)
  end

  def add_log(obj)
    unpersisted_logs << obj.to_json
  end

  protected

  def ensure_processing_errors_and_warnings
    self.processing_errors ||= []
    self.processing_warnings ||= []
  end

  private

  def unpersisted_logs
    @unpersisted_logs ||= []
  end

  def persist_logs
    return if unpersisted_logs.empty?

    if log_file.present?
      existing_logs = load_logs
      existing_logs << "\n" + unpersisted_logs.join("\n")
      FileStorage.default.save_file(log_file, existing_logs)
    else
      self.log_file = "import-#{id}.log" # TODO: have file storage allow subdirectories e.g. `import-logs/import-id.log`
      FileStorage.default.save_file(log_file, unpersisted_logs.join("\n"))
    end

    @unpersisted_logs = []
  end
end
