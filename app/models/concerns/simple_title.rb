# frozen_string_literal: true

module SimpleTitle
  extend ActiveSupport::Concern

  included do
    before_save :normalize_title
  end

  class_methods do
    # A class using this concern can provide its own implementation of
    # normalize_title_string(string) to customize the normalization.
    def normalize_title_string(title)
      title.strip.gsub(/\s+/, ' ')
    end
  end

  protected

  def normalize_title
    self.title = self.class.normalize_title_string(title) if title.present?
  end
end
