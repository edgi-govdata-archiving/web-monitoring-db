# frozen_string_literal: true

# MergedPage keeps track of pages that were merged into others so we can
# support old links by redirecting to the page they were merged into.
# - The primary key is the ID of the page that was merged and removed
# - `target_uuid` is the ID of the page it was merged into
# - `audit_data` is any useful JSON data about the page (usually a frozen
#   copy of its attributes).
class MergedPage < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :target,
             class_name: 'Page',
             foreign_key: :target_uuid,
             required: true
end
