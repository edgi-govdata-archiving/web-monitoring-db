module Differ
  # Register a differ instance to be used for a given diff type. If `type` is
  # nil, the differ will be treated as the constructor arguments for a differ
  # to use when no matching diff type is found for registry lookups.
  def self.register(type, differ)
    @type_map ||= {}.with_indifferent_access
    @type_map[type] = differ
  end

  # Retrieve the differ associated with a given diff type
  def self.for_type(type)
    (@type_map && @type_map[type]) || default_for_type(type)
  end

  def self.for_type!(type)
    for_type(type) || (raise Api::NotImplementedError,
                             "There is no registered differ for '#{type}'")
  end

  # If configured, create a default/fallback differ for a given type.
  def self.default_for_type(type)
    value = @type_map && @type_map[nil]
    if value.is_a?(String)
      SimpleDiff.new(value, type)
    elsif value.respond_to?(:diff)
      value
    end
  end

  # Hint for other tools to expire cached diffs older than this date.
  # This provides a really simple (if imprecise) mechanism for expiring cached
  # diffs when a diff algorithm is updated. Note that this is broad, though:
  # updating this date will expire all diff types.
  def self.cache_date
    @cache_date ||= Time.new(2000, 1, 1)
  end

  def self.cache_date=(time)
    @cache_date = time
  end
end
