module Taggable
  extend ActiveSupport::Concern

  included do
    has_many :taggings, as: :taggable, foreign_key: 'taggable_uuid', dependent: :delete_all
    has_many :tags, through: :taggings, dependent: nil
  end

  def add_tag(tag)
    tag = Tag.find_or_create_by(name: tag.strip) unless tag.is_a?(Tag)
    tags.push(tag) unless tags.include?(tag)
    tag
  end

  def untag(tag)
    attached_tag =
      if tag.is_a?(Tag)
        tags.find_by(uuid: tag.uuid)
      else
        tags.find_by(name: tag.strip)
      end
    tags.delete(attached_tag) if attached_tag
  end

  def tag_names
    tags.collect(&:name)
  end
end
