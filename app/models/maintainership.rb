# frozen_string_literal: true

class Maintainership < ApplicationRecord
  belongs_to :maintainer, foreign_key: :maintainer_uuid
  belongs_to :page, foreign_key: :page_uuid

  # A smarter implementation might support all the normal options, but we
  # don't have any other use cases right now, so maybe not worth the effort.
  def as_json(_options = {})
    {
      'uuid' => maintainer_uuid,
      'name' => maintainer.name,
      'assigned_at' => created_at,
      'parent_uuid' => maintainer.parent_uuid
    }
  end
end
