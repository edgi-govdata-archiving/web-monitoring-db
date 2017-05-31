module Differ
  @@type_map = nil

  # Register a differ instance to be used for a given diff type
  def self.register(type, differ)
    @@type_map ||= {}.with_indifferent_access
    @@type_map[type] = differ
  end

  # Retrieve the differ associated with a given diff type
  def self.for_type(type)
    @@type_map ? @@type_map[type] : nil
  end

  def self.for_type!(type)
    for_type(type) || (raise Api::NotImplementedError,
      "There is no registered differ for '#{type}'")
  end
end
