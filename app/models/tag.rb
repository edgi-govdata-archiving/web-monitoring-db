# frozen_string_literal: true

class Tag < ApplicationRecord
  include UuidPrimaryKey

  has_many :taggings, foreign_key: :tag_uuid
  has_many :pages, through: :taggings, source: :taggable, source_type: :Page

  def self.merge(final_tag, old_tag)
    final_tag = find_or_create_by(name: final_tag.strip) unless final_tag.is_a?(Tag)
    old_tag = find_by(name: old_tag.strip) unless old_tag.is_a?(Tag)

    return if old_tag.nil?
    return if old_tag == final_tag

    old_tag.taggings.each do |tagging|
      if Tagging.exists?(taggable_uuid: tagging.taggable_uuid, tag_uuid: final_tag.uuid)
        tagging.destroy
      else
        tagging.update(tag_uuid: final_tag.uuid)
      end
    end

    old_tag.destroy
  end
end
