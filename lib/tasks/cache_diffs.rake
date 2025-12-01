# frozen_string_literal: true

DEFAULT_DIFF_TYPES = [
  'html_token?include=all',
  'html_token?include=combined',
  'html_source_dmp'
].freeze

desc 'Generate and cache common diffs of a page. Specify diff types as a variable-length list of arguments after the page ID.'
task :cache_page_diffs, [:page_uuid] => [:environment] do |_t, args|
  raw_types = args.extras.length.positive? ? args.extras : DEFAULT_DIFF_TYPES
  diff_types = parse_diff_types(raw_types)

  page = Page.find(args[:page_uuid])
  next unless page.versions.count > 1

  # We're actually using reduce as a shortcut for iterating through pairs,
  # rather than reducing the collection to some single value.
  # rubocop:disable Lint/UnmodifiedReduceAccumulator
  page.versions.reduce do |a, b|
    change = Change.between(to: a, from: b)
    cache_change_diffs(change, diff_types)
    puts "Cached #{change.api_id}"
    b
  end
  # rubocop:enable Lint/UnmodifiedReduceAccumulator

  next unless page.versions.count > 2

  latest_to_base = Change.between(to: page.versions.first, from: page.versions.last)
  cache_change_diffs(latest_to_base, diff_types)
  puts "Cached #{latest_to_base.api_id} (Latest to Base)"
end


desc 'Generate and cache diffs of a change (with ID `{uuid}..{uuid}`). Specify diff types as a variable-length list of arguments after the page ID.'
task :cache_change_diffs, [:change_id] => [:environment] do |_t, args|
  raw_types = args.extras.length.positive? ? args.extras : DEFAULT_DIFF_TYPES
  diff_types = parse_diff_types(raw_types)

  change = Change.find_by_api_id(args[:change_id])
  cache_change_diffs(change, diff_types)
  puts "Cached #{change.api_id}"
end


def cache_change_diffs(change, diff_types)
  diff_types.each do |diff_type, options|
    Differ.for_type!(diff_type).diff(change, options)
  end
end

def parse_diff_types(type_list)
  type_list.collect do |type_string|
    next [type_string, {}] unless type_string.include?('?')

    uri = URI.parse(type_string)
    options = uri.query.split('&').collect do |raw_item|
      raw_item.split('=').collect { |x| URI.decode_www_form_component(x) }
    end

    [uri.path, options.to_h]
  end
end
