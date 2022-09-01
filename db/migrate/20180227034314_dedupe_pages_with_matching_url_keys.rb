class DedupePagesWithMatchingUrlKeys < ActiveRecord::Migration[5.1]
  # Find all pages sharing the same `url_key` and de-duplicate them by copying
  # the maintainers, tags, and versions of all subsequent pages onto the one
  # that was created first.
  def up
    total_deletions = 0

    Page.group(:url_key).having('count(*) > 1').count.each_key do |url_key|
      say("Deduplicating pages for '#{url_key}'")

      canonical_page = nil
      deletable = []
      pages = Page.where(url_key:)
        .eager_load(:maintainers, :tags)
        .order(created_at: :asc)

      pages.each do |page|
        if canonical_page.nil?
          canonical_page = page
        else
          page.maintainers.each {|item| canonical_page.add_maintainer(item)}
          page.maintainers.clear

          page.tags.each {|item| canonical_page.add_tag(item)}
          page.tags.clear

          page.versions.update_all(page_uuid: canonical_page.uuid)
          deletable << page.uuid
        end
      end

      Page.where(uuid: deletable).delete_all
      say("Deleted #{deletable.length} pages.", true)

      total_deletions += deletable.length
    end

    say("Deleted #{total_deletions} pages in total.")
  end

  def down
    total_creations = 0

    # Crazy Arel join time! Maybe would have been easier to just write SQL...
    pages = Page.arel_table
    versions = Version.arel_table
    condition = versions.create_on(versions[:capture_url].eq(pages[:url]))
    join_on_url = versions.create_join(pages, condition, Arel::Nodes::OuterJoin)
    urls_with_no_page = Version
      .joins(join_on_url)
      .where(pages[:url].eq(nil))
      .distinct
      .pluck(:capture_url)

    urls_with_no_page.each do |url|
      say("Recreating page for '#{url}'")

      # This will fall back to url_key and find our existing page
      page = Page.find_by_url(url)
      values = page.attributes.except('uuid').merge(url:)

      new_page = Page.create(values)
      page.maintainers.each {|item| new_page.add_maintainer(item)}
      page.tags.each {|item| new_page.add_tag(item)}
      Version.where(capture_url: url).update_all(page_uuid: new_page.uuid)

      total_creations += 1
    end

    say("Created #{total_creations} pages in total.")
  end
end
