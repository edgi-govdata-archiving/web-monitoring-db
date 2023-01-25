class RemoveSimpleTimeIndexesOnVersions < ActiveRecord::Migration[7.0]
  def change
    # Drop indexes on Version time fields. These are now redundant since we
    # have compound indexes (with UUID) that can be used in the cases these
    # were designed for.
    remove_index(:versions, :created_at)
    remove_index(:versions, :capture_time)

    # Similarly, these partial indexes are no longer heavily used
    remove_index(:versions, :capture_time,
                 where: 'different = true',
                 name: 'index_different_versions_on_capture_time')
    remove_index(:versions, :created_at,
                 where: 'different = true',
                 name: 'index_different_versions_on_created_at')
  end
end
