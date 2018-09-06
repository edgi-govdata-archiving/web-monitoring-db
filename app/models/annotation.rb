class Annotation < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :change, foreign_key: :change_uuid, required: true, inverse_of: :annotations
  belongs_to :author, class_name: 'User', foreign_key: :author_id, required: true
  validate :annotation_must_be_an_object
  validate :priority_in_range
  validate :significance_in_range

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

  def priority_in_range
    property_in_range('priority')
  end

  def significance_in_range
    property_in_range('significance')
  end

  def property_in_range(property, range: 0..1)
    value = annotation && annotation.is_a?(Hash) && annotation[property]
    return if value.nil?

    if !value.is_a?(Numeric)
      errors.add(:annotation, ".#{property} must be a number")
    elsif !range.cover?(value)
      errors.add(:annotation, ".#{property} must be between #{range.begin} and #{range.end}")
    end
  end
end
