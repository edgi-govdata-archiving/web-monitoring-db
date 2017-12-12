require_dependency 'differ/differ'
require_dependency 'differ/simple_diff'

# Automatically create SimpleDiff instances with the name of whatever is after
# "DIFFER_" in the name of the following env vars.
ENV.each do |key, value|
  if key == 'DIFFER_DEFAULT'
    # The differ registered with a nil key is actually constructor arguments,
    # not a differ instance.
    Differ.register(nil, value)
  elsif key.start_with?('DIFFER_')
    Differ.register(
      key.gsub(/^DIFFER_/, '').downcase.to_sym,
      Differ::SimpleDiff.new(value)
    )
  end
end

unless Differ.for_type(nil)
  Rails.logger.warn('No default differ registered for unknown types! To register a default, set the DIFFER_DEFAULT environment variable.')
end
