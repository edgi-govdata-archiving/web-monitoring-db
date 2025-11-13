# frozen_string_literal: true

desc 'Merge multiple pages together. Pages will be merged *into* the first listed.'
task :merge_pages, [] => :environment do |_t, args|
  DataHelpers.with_activerecord_log_level(:error) do
    pages = Page.where(uuid: args.extras)
    base, *removals = pages

    puts "Merging #{removals.length} other pages into #{base.uuid}..."
    base.merge(*removals)
  end
end
