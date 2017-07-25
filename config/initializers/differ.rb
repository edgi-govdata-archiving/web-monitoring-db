require_dependency 'differ/differ'
require_dependency 'differ/simple_diff'

if ENV['DIFFER_SOURCE']
  Differ.register(:source, Differ::SimpleDiff.new(ENV['DIFFER_SOURCE']))
end

if ENV['DIFFER_LENGTH']
  Differ.register(:length, Differ::SimpleDiff.new(ENV['DIFFER_LENGTH']))
end

if ENV['DIFFER_IDENTICAL_BYTES']
  Differ.register(:identical_bytes,
                  Differ::SimpleDiff.new(ENV['DIFFER_IDENTICAL_BYTES']))
end

if ENV['DIFFER_SIDE_BY_SIDE_TEXT']
  Differ.register(:side_by_side_text,
                  Differ::SimpleDiff.new(ENV['DIFFER_SIDE_BY_SIDE_TEXT']))
end

if ENV['DIFFER_PAGEFREEZER']
  Differ.register(:pagefreezer, Differ::SimpleDiff.new(ENV['DIFFER_PAGEFREEZER']))
end

if ENV['DIFFER_HTML_SOURCE']
  Differ.register(:html_source, Differ::SimpleDiff.new(ENV['DIFFER_HTML_SOURCE']))
end

if ENV['DIFFER_HTML_TEXT']
  Differ.register(:html_text, Differ::SimpleDiff.new(ENV['DIFFER_HTML_TEXT']))
end
