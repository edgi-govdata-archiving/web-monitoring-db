class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true, foreign_key: :taggable_uuid
  belongs_to :tag, inverse_of: :taggings, foreign_key: :tag_uuid

  # A smarter implementation might support all the normal options, but we
  # don't have any other use cases right now, so maybe not worth the effort.
  def as_json(_options = {})
    {
      'uuid' => tag_uuid,
      'name' => tag.name,
      'assigned_at' => created_at
    }
  end
end
