class AddIndexesForImporting < ActiveRecord::Migration[5.0]
  def change
    add_index :versions, :capture_time

    # This index should be removed when we address
    # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/24
    add_index :pages, [:uuid, :site]
  end
end
