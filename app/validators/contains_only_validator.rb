class ContainsOnlyValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value.is_a?(Array)
      record.errors.add(attribute, 'must be an array')
      return
    end

    unless (value - options[:in]).empty?
      record.errors.add(attribute, 'not a valid value')
    end
  end
end
