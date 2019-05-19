class NumericInterval
  attr_reader :start
  attr_reader :start_open
  attr_reader :end
  attr_reader :end_open

  def initialize(string_interval)
    components = string_interval.match(/^\s*(\[|\()?\s*(\d*(?:\.\d+)?)\s*(?:,|\.\.)\s*(\d*(?:\.\d+)?)\s*(\]|\))?\s*$/)
    raise ArgumentError, "Invalid interval format: '#{string_interval}'" unless components

    @start = components[2].present? ? components[2].to_f : nil
    @end = components[3].present? ? components[3].to_f : nil
    @start_open = components[1] == '('
    @end_open = components[4] == ')'
    raise ArgumentError, 'An interval must have at least a start or end.' unless @start || @end
    raise ArgumentError, 'The start of an interval must be less than its end' if @start && @end && @start >= @end
  end

  def to_s
    start_token = start_open ? '(' : '['
    end_token = end_token ? ')' : ']'
    "#{start_token}#{start},#{self.end}#{end_token}"
  end

  def include?(value)
    if start
      return false if value < start
      return false if value == start && start_open
    end

    if self.end
      return false if value > self.end
      return false if value == self.end && end_open
    end

    true
  end
end
