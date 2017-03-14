class Annotation < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :change, foreign_key: :change_uuid, required: true, inverse_of: :annotations
  belongs_to :author, class_name: 'User', foreign_key: :author_id, required: false
  validate :annotation_must_be_an_object

  protected

  def annotation_must_be_an_object
    if annotation.nil? || !annotation.kind_of?(Hash)
      errors.add(:annotation, "must be an object, not a #{annotation.class.name}")
    end
  end
end
