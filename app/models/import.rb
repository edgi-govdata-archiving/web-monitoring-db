class Import < ApplicationRecord
  belongs_to :user
  enum status: [:pending, :processing, :complete]
  validates :file, presence: true
  after_initialize :ensure_processing_errors

  protected

  def ensure_processing_errors
    self.processing_errors ||= []
  end
end
