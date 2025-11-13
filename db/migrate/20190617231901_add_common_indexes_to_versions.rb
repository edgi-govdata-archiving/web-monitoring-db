# frozen_string_literal: true

class AddCommonIndexesToVersions < ActiveRecord::Migration[5.2]
  # Add indexes to support some common queries we do that should be faster.
  def change
    # Our default sorting is by created_at:asc.
    add_index :versions, :created_at
    # We also search by source_type pretty frequently.
    add_index :versions, :source_type

    # In most cases, we only search for records where different = true.
    # However, an index for `different` or a compound index featuring it
    # will almost never get used in practice! Instead, create partial
    # indexes, which do get used.
    add_index :versions, :capture_time,
              where: 'different = true',
              name: 'index_different_versions_on_capture_time'
    add_index :versions, :created_at,
              where: 'different = true',
              name: 'index_different_versions_on_created_at'
  end
end
