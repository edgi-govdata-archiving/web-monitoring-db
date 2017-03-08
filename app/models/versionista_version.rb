class VersionistaVersion < ApplicationRecord
  belongs_to :page, class_name: 'VersionistaPage', inverse_of: :versions
  has_one :previous, class_name: 'VersionistaVersion'

  def view_url
    diff_with_previous_url.sub(/:\w+\/?$/, '/')
  end

  def annotations
    super || []
  end

  def current_annotation
    super || {}
  end

  def annotate(annotation, author = nil)
    if annotation.blank?
      return
    end

    if !annotation.kind_of?(Hash)
      raise 'Annotations must be objects, not arrays or other data.'
    end

    envelope = {
      id: SecureRandom.uuid,
      version_id: self.id,
      created_at: DateTime.now.utc.iso8601,
      annotation: annotation
    }

    if author
      envelope[:author] = author.email
    end

    annotations = self.annotations
    annotations << envelope
    self.annotations = annotations

    update_current_annotation(annotation)
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
    self.current_annotation = self.current_annotation.with_indifferent_access
      .merge(new_annotation.with_indifferent_access)
      .delete_if {|key, value| value.nil?}
  end

end
