class Change < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :version, foreign_key: :uuid_to, required: true
  belongs_to :from_version, class_name: 'Version', foreign_key: :uuid_from, required: true
  has_many :annotations, -> { order(updated_at: :asc) }, foreign_key: 'change_uuid', inverse_of: :change
  validate :from_must_be_before_to_version
  validates :priority, allow_nil: true, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1
  }
  validates :significance, allow_nil: true, numericality: {
    greater_than_or_equal_to: 0,
    less_than_or_equal_to: 1
  }

  def self.between(from:, to:, create: false)
    return nil if from.nil? || to.nil?
    change_definition = {
      uuid_from: from.is_a?(Version) ? from.uuid : from,
      uuid_to: to.is_a?(Version) ? to.uuid : to
    }
    instantiator = create ? :create : :new
    self.where(change_definition).first ||
      self.send(instantiator, change_definition)
  end

  # Look up a Change model by its actual ID or by a "{from_id}..{to_id}" string
  def self.find_by_api_id(api_id)
    return nil if api_id.blank?

    if api_id.include?('..')
      from_id, to_id = api_id.split('..')
      if from_id.present? && to_id.present?
        Change.between(from: from_id, to: to_id)
      elsif from_id.present?
        Version.find(from_id).change_from_next ||
          (raise ActiveRecord::RecordNotFound, "There is no version following
            #{from_id} to change to.")
      else
        Version.find(to_id).change_from_previous ||
          (raise ActiveRecord::RecordNotFound, "There is no version prior to
            #{to_id} to change from.")
      end
    else
      Change.find(api_id)
    end
  end

  def api_id
    "#{uuid_from}..#{uuid_to}"
  end

  def current_annotation
    super ||
      if persisted?
        regenerate_current_annotation
      else
        {}
      end
  end

  def annotate(data, author)
    if data.blank?
      return
    end

    if !data.is_a?(Hash)
      raise 'Annotations must be objects, not arrays or other data.'
    end

    if !self.persisted?
      self.save!
    end

    annotation = annotations.find_or_initialize_by(author: author)
    annotation.annotation = data
    annotation.save!

    annotations.reload
    regenerate_current_annotation
    update_from_annotation

    annotation
  end

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
  def regenerate_current_annotation
    self.current_annotation = annotations.reduce({}) do |merged, annotation|
      merge_annotations(merged, annotation.annotation)
    end
  end

  protected

  def update_from_annotation
    updates = {
      priority: current_annotation['priority'],
      significance: current_annotation['significance']
    }.compact
    update(updates) unless updates.empty?
  end

  def merge_annotations(base, updates)
    base.with_indifferent_access
      .merge(updates.with_indifferent_access)
      .delete_if {|_, value| value.nil?}
  end

  def from_must_be_before_to_version
    if from_version && version && from_version.capture_time >= version.capture_time
      errors.add(:from_version, 'must be an earlier version than the ending version')
    end
  end
end
