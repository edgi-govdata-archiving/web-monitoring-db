module SortingConcern
  extend ActiveSupport::Concern

  protected

  def sorting_params
    raw = params[:sort] || ''
    raw.split(',').collect(&method(:sql_order_for_param))
  end

  def sql_order_for_param(param)
    field, direction = param.split(':')
    { sanitize_field_name!(field) => sanitize_direction!(direction) }
    # "#{sanitize_field_name!(field)} #{sanitize_direction!(direction)}"
  end

  def sanitize_field_name!(field)
    sanitized = field.strip
    unless sanitized.match?(/^\w+$/)
      raise Api::InputError, "'#{field}' is not a valid attribute name for sorting"
    end

    sanitized.to_sym
  end

  def sanitize_direction!(direction)
    direction = 'asc' if direction.blank?
    sanitized = direction.strip.downcase
    unless ['asc', 'desc'].include?(sanitized)
      raise Api::InputError, "'#{direction}' is not a valid sort direction. It must be either 'asc' or 'desc'"
    end

    sanitized.to_sym
  end

  def sort_using_params(collection)
    sort = sorting_params
    if sort.present?
      collection.reorder(sort)
    else
      collection
    end
  end
end
