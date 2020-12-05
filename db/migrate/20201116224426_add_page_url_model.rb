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
  end
end
