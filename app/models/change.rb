class Change < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :version, foreign_key: :uuid_to, required: true
  belongs_to :from_version, class_name: 'Version', foreign_key: :uuid_from, required: true
  has_many :annotations, foreign_key: 'change_uuid', inverse_of: :change
  validate :from_must_be_before_to_version

  def self.between(to:, from: nil, create: false)
    from ||= to.previous
    change_definition = {from_version: from, version: to}
    instantiator = create ? :create : :new
    self.where(change_definition).first ||
      self.send(instantiator, change_definition)
  end

  def current_annotation
    super || if persisted?
      regenerate_current_annotation
    else
      {}
    end
  end

  def annotate(data, author = nil)
    if data.blank?
      return
    end

    if !data.kind_of?(Hash)
      raise 'Annotations must be objects, not arrays or other data.'
    end

    if !self.persisted?
      self.save
    end

    annotation = Annotation.create(
      change_uuid: self.uuid,
      author: author,
      annotation: data
    )

    if annotation.valid?
      update_current_annotation(annotation.annotation)
    end

    annotation
  end

  def regenerate_current_annotation
    self.current_annotation = annotations.reduce({}) do |merged, annotation|
      merge_annotations(merged, annotation.annotation)
    end
  end

  protected

  # Update the `current_annotation property, which is a materialized view of
  # all annotations stacked together. If a property does not exist in the
  # the current annotation, it simply does not affect the materialized
  # property. However, if the property is explicitly set to null, it will be
  # removed from the materialized annotation.
  #
  # Example: the following annotations:
  #   {"a": "one", "b": "two", "c": "three"}
  #   {"a": "Not one anymore!", "b": null}
  #
  # Result in this materialized annotation:
  #   {"a": "Not one anymore!", "c": "three"}
  #
  def update_current_annotation(new_annotation)
    self.current_annotation = merge_annotations(self.current_annotation, new_annotation)
  end

  def merge_annotations(base, updates)
    base.with_indifferent_access
      .merge(updates.with_indifferent_access)
      .delete_if {|key, value| value.nil?}
  end

  def from_must_be_before_to_version
    if from_version.capture_time >= version.capture_time
      errors.add(:from_version, "must be an earlier version than the ending version")
    end
  end
end
