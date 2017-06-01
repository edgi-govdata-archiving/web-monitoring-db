require_dependency 'differ/differ'
require_dependency 'differ/simple_diff'

if ENV['DIFFER_SOURCE']
  Differ.register(:source, Differ::SimpleDiff.new(ENV['DIFFER_SOURCE']))
end
