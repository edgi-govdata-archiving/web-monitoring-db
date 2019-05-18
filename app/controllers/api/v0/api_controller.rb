class Api::V0::ApiController < ApplicationController
  include PagingConcern
  before_action :require_authentication!
  before_action :set_environment_header

  rescue_from StandardError, with: :render_errors if Rails.env.production?
  rescue_from Api::ApiError, with: :render_errors

  rescue_from ActiveRecord::RecordInvalid, with: :render_errors
  rescue_from ActiveModel::ValidationError do |error|
    render_errors(error.model.errors.full_messages, 422)
  end


  protected

  def paging_url_format
    ''
  end

  # This is different from Devise's authenticate_user! -- it does not redirect.
  def require_authentication!
    unless user_signed_in?
      raise Api::AuthorizationError, 'You must be logged in to perform this action.'
    end
  end

  # Render an error or errors as a proper API response
  def render_errors(errors, status_code = nil)
    errors = [errors] unless errors.is_a?(Array)
    status_code ||= status_code_for(errors.first)

    render status: status_code, json: {
      errors: errors.collect do |error|
        {
          status: status_code,
          title: message_for(error)
        }
      end
    }
  end

  def status_code_for(error)
    code = error.try(:status_code)

    code || begin
      error_name = error.class.name
      ActionDispatch::ExceptionWrapper.status_code_for_exception(error_name)
            rescue StandardError => _error
              500
    end
  end

  def message_for(error)
    error.try(:message) ||
      (error.try(:has_key?, :message) && error.send(:[], :message)) ||
      error.to_s
  end

  def boolean_param(param, presence_implies_true: true, default: false)
    return default unless params.key?(param)

    value = params[param]
    return true if value.nil? && presence_implies_true

    /^(true|t|1)$/i.match? value
  end

  # Returns a boolean OR nil for this param Unlike boolean params above, this
  # will return nil for `?param` and `?param=`. To get a true or false, the
  # querystring must explicitly set it. (`?param=true`, `?param=false`, etc.)
  def nullable_boolean_param(param)
    value = params[param]
    return nil unless value.present?

    /^(true|t|1)$/i.match?(value.downcase.strip)
  end

  def parse_date!(date)
    raise 'Nope' unless date.match?(/^\d{4}-\d\d-\d\d(T\d\d\:\d\d(\:\d\d(\.\d+)?)?(Z|([+\-]\d\d:?\d\d)))?$/)

    Time.parse date
  rescue StandardError => _error
    raise Api::InputError, "Invalid date: '#{date}'"
  end

  def parse_unbounded_range!(string_range, param = nil)
    return nil unless string_range

    if string_range.include? '..'
      from, to = string_range.split(/\.\.\.?/)
      from = from.present? ? (yield from) : nil
      to = to.present? ? (yield to) : nil

      if from.nil? && to.nil?
        name = param ? "#{param} range" : 'Range'
        raise Api::InputError, "#{name} must have a start or end"
      end

      [from, to]
    else
      yield string_range
    end
  end

  # TODO: use new NumericInterval class for unbounded [date] ranges
  def where_in_range_param(collection, name, attribute = nil, &parse)
    return collection unless params[name]

    attribute = name if attribute.nil?
    range = parse_unbounded_range!(params[name], name, &parse)
    collection.where_in_unbounded_range(attribute, range)
  end

  def where_in_interval_param(collection, name, attribute = nil)
    value = params[name]
    return collection unless value

    attribute = name if attribute.nil?
    if value.match?(/^\d/)
      collection.where(attribute => Float(value))
    else
      collection.where_in_interval(attribute, value)
    end
  end

  private

  def set_environment_header
    response['X-Environment'] = Rails.env
  end
end
