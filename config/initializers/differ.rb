require_dependency 'differ/differ'
require_dependency 'differ/simple_diff'

# Automatically create SimpleDiff instances with the name of whatever is after
# "DIFFER_" in the name of the following env vars.
[
  'DIFFER_SOURCE',
  'DIFFER_LENGTH',
  'DIFFER_IDENTICAL_BYTES',
  'DIFFER_SIDE_BY_SIDE_TEXT',
  'DIFFER_PAGEFREEZER',
  'DIFFER_HTML_SOURCE',
  'DIFFER_HTML_TEXT',
  'DIFFER_HTML_VISUAL'
].each do |env_var|
  if ENV[env_var]
    Differ.register(
      env_var.gsub(/^DIFFER_/, '').downcase.to_sym,
      Differ::SimpleDiff.new(ENV[env_var])
    )
  end
end
