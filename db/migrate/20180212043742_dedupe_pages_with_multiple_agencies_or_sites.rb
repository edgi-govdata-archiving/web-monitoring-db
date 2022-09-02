class DedupePagesWithMultipleAgenciesOrSites < ActiveRecord::Migration[5.1]
  # Find all pages sharing the same URL and de-duplicate them by copying the
  # maintainers, tags, and versions of all subsequent pages onto the one that
  # was created first.
  def up
    total_deletions = 0

    Page.group(:url).having('count(*) > 1').count.each_key do |url|
      say("Deduplicating pages for '#{url}'")

      canonical_page = nil
      deletable = []
      pages = Page.where(url:)
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
    raise ActiveRecord::IrreversibleMigration,
          'This migration removed information and cannot be reversed.'
  end
end
