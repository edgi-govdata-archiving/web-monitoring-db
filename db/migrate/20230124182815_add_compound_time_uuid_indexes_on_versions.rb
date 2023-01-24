class AddCompoundTimeUuidIndexesOnVersions < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def change
    # The versions table has gotten so big that offset-based queries are a real
    # problem, so we need to paginate by the actual sort critera
    # (created/captured time), which requires a compound index with UUID to make
    # sure we never skip versions with identical timestamps.
    add_index(:versions, [:created_at, :uuid], algorithm: :concurrently)
    add_index(:versions, [:page_uuid, :created_at, :uuid], algorithm: :concurrently)
    add_index(:versions, [:capture_time, :uuid], algorithm: :concurrently)
    add_index(:versions, [:page_uuid, :capture_time, :uuid], algorithm: :concurrently)

    # NOTE: this leaves simpler indexes like just created_at, just capture_time
    # in place for now. We can remove them once the above indexes are validated.
  end
end
