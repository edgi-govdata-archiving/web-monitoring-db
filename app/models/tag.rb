class Tag < ApplicationRecord
  include UuidPrimaryKey
  has_many :taggings, foreign_key: :tag_uuid
  has_many :pages, through: :taggings, source: :taggable, source_type: :Page
end
