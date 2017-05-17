class Annotation < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :change, foreign_key: :change_uuid, required: true, inverse_of: :annotations
  belongs_to :author, class_name: 'User', foreign_key: :author_id, required: true
  validate :annotation_must_be_an_object

  def as_json(options = nil)
    result = super(options)

    if result['change_uuid']
      result.delete('change_uuid')
      result['from_version'] = self.change.from_version.uuid
      result['to_version'] = self.change.version.uuid
    end

    result
  end

  protected

  def annotation_must_be_an_object
    if annotation.nil? || !annotation.is_a?(Hash)
      errors.add(:annotation, "must be an object, not a #{annotation.class.name}")
    end
  end
end
