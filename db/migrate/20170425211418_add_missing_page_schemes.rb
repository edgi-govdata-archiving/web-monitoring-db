# frozen_string_literal: true

class AddMissingPageSchemes < ActiveRecord::Migration[5.0]
  def up
    Page.where("url NOT LIKE 'http://%' AND url NOT LIKE 'https://%' AND url NOT LIKE 'ftp://%'").each(&:save)
  end

  def down
    raise ActiveRecord::IrreversibleMigration,
          'This migration modifies existing bad data and cannot be reversed.'
  end
end
