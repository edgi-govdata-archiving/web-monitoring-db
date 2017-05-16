class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def self.where_in_unbounded_range(attribute, range, exact = true)
    result = self

    if attribute.is_a?(String) && attribute.include?('.')
      join_model = attribute.split('.')[0].to_sym
      result = result.joins(join_model)
    end

    if range.is_a? Array
      result = result.where("#{attribute} >= ?", range[0]) if range[0]
      result = result.where("#{attribute} <= ?", range[1]) if range[1]
    elsif exact
      result = result.where("#{attribute} = ?", range)
    else
      raise StandardError, 'Range must be an array in `where_in_unbounded_range`'
    end

    result
  end
end
