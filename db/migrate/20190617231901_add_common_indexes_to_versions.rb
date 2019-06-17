class AddCommonIndexesToVersions < ActiveRecord::Migration[5.2]
  # Add indexes to support some common queries we do that should be faster.
  def change
    # Our default sorting is by created_at:asc.
    add_index :versions, :created_at
    # By default, we only search for records where `different = true`.
    add_index :versions, :different
    # We also search by source_type pretty frequently.
    add_index :versions, :source_type
  end
end
