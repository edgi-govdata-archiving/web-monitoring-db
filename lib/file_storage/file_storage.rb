# frozen_string_literal: true

require_relative 'local_file'

module FileStorage
  def self.default
    @default ||= FileStorage::LocalFile.new
  end

  def self.default=(storage)
    @default = storage
  end
end
