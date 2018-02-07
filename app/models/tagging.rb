class Tagging < ApplicationRecord
  belongs_to :taggable, polymorphic: true, foreign_key: :taggable_uuid
  belongs_to :tag, inverse_of: :taggings, foreign_key: :tag_uuid
end
