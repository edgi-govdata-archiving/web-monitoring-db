module SortingConcern
  extend ActiveSupport::Concern

  protected

  # Sorting params example: capture_time:desc,title:asc
  def sortation(sort_params)
    return if sort_params.nil?

    sort_params.split(',')
               .map { |sort| ordering(sort) }
               .join(', ')
    end
  end

  private

  def ordering(sort)
    key, direction = sort.split(':')

    "#{key} #{sanitize_direction(direction)}"
  end

  def sanitize_direction(direction)
    sanitized_direction = direction.downcase || 'asc'
    sanitized_direction = 'asc' unless %w(asc desc).include?(sanitized_direction)

    sanitized_direction
  end
end
