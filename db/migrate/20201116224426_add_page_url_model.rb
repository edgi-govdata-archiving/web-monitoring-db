class AddPageUrlModel < ActiveRecord::Migration[6.0]
  def change
    create_table :page_urls, id: false do |t|
      t.primary_key :uuid, :uuid
      # No way to use `belongs_to/references` to make a column named `*_uuid`
      t.uuid :page_uuid, null: false
      t.string :url, null: false
      t.string :url_key, null: false

      # NOTE: The `tsrange` type would be much more suitable here, BUT Rails
      # handles it poorly, especially when it comes to ranges where there are
      # no bounds or the bounds are +/-infinity (which is our most common
      # case). For details, see:
      #   - https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/492#issuecomment-738523165
      #   - https://github.com/rails/rails/issues/39833
      #   ex: `t.tsrange :timeframe, null: false, default: '[-infinity,infinity]'`
      #
      # We don't allow these to be null and instead use +/-infinity to keep
      # queries straightforward. Note this also impacts indexing: Postgres
      # index ignore NULL values, so using +/-infinity here helps make sure
      # all rows are indexed and *ensured to be unique*.
      t.datetime :from_time, null: false, default: '-infinity'
      t.datetime :to_time, null: false, default: 'infinity'

      t.string :notes
      t.timestamps

      t.foreign_key :pages, column: :page_uuid, primary_key: 'uuid'
      t.index :url
      t.index :url_key
      # NOTE: this index depends on from_time/to_time not being nullable.
      # If we ever make them nullable, the index will need to use:
      #   `coalesce(from_time, '-infinity'::timestamp)`
      # Because otherwise Postgres will ignore NULLs in the index.
      #
      # NOTE: the unique index helps make sure we don't make really
      # bone-headed mistakes, but it does not prevent us from creating
      # problematic, overlapping timeframes.
      #   - Constraining this at the DB level is hard without using tsrange,
      #     and tsrange has issues in Rails (see above).
      #   - The timeframe values are really more of a guess, and could change
      #     if/when we pull in versions that were missed, or new data from
      #     another archival source, so making serious guarantees about
      #     overlapping timeframes may not be reasonable or feasible anyway.
      t.index [:page_uuid, :url, :from_time, :to_time], unique: true
    end

    # Stores information about pages that have been merged into others so we
    # can support old links by redirecting the new page.
    create_table :merged_pages, id: false do |t|
      t.primary_key :uuid, :uuid
      t.uuid :target_uuid, null: false
      t.jsonb :audit_data

      # Needed for reverse lookups to update references if a page that was
      # previously merged into is itself later merged into another page.
      t.index :target_uuid
    end

    # As part of this, we anticipate orphaning some version records. That's
    # OK -- we've been slowly loosening the conceptual model from Pages-with-
    # -Versions-of-those-pages to Versions-are-records-of-urls-at-a-point-in-
    # time-and-Pages-are-conceptual-models-by-which-they-might-be-grouped.
    #
    # They no longer have an especially strict relationship to each other, and
    # Pages are less a technical reflection of web mechanics and more a
    # conceptual tool for analysis. (Hopefully that makes some sense.)
    #
    # Here's an example scenario where we may need to orphan some Versions...
    # Consider two pages we might have today:
    #
    #   Page A=https://example.gov/a
    #   Page B=https://example.gov/b
    #
    # 1. Page B didn't originally exist, but was created when Page A was
    #    moved to that URL.
    # 2. For a while, Page A redirected to Page B, versions attached to each
    #    of them have the same content.
    # 3. Then Page A became a 404 page, so versions attached to A have
    #    different content than those attached to B.
    #
    # A and B are the same conceptual page here, and now that we can support
    # multiple URLs, we'd like to merge them. However, putting all the
    # versions together would work fine right up until the point in time where
    # A started responding with a 404 status code. Versions after that time
    # will show up in our new, unified page's timeline as interleaved 200 and
    # 404 responses, which is very confusing. To handle this, it should be
    # possible to remove those 404 versions from the page. However, they have
    # nowhere to go at this point, and no conceptual "page" that they really
    # belong to.
    change_column_null(:versions, :page_uuid, true)
  end
end
