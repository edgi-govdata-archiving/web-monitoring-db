class Api::V0::ApiController < ApplicationController
  skip_forgery_protection

  include PagingConcern
  before_action { authorize :api, :view? }
  before_action :set_environment_header

  rescue_from StandardError, with: :render_errors
  rescue_from Pundit::NotAuthorizedError, with: :pundit_auth_error
  rescue_from ActiveModel::ValidationError do |error|
    render_errors(error.model.errors.full_messages, 422)
  end


  protected

  def paging_url_format
    ''
  end

  def pundit_auth_error(error)
    api_error = if user_signed_in?
                  Api::ForbiddenError.new('You are not authorized to perform this action.')
                else
                  Api::AuthorizationError.new('You must be logged in to perform this action.')
                end

    api_error.set_backtrace(error.backtrace)
    render_errors(api_error)
  end

  # Render an error or errors as a proper API response
  def render_errors(errors, status_code = nil)
    errors = Array(errors)
    # Bail out and let Rails present a nice debugging page if using a *browser*.
    raise errors.first if Rails.env.development? && request.format.html? && errors.length == 1

    status_code ||= status_code_for(errors.first)

    render status: status_code, json: {
      errors: errors.collect do |error|
        formatted = {
          status: status_code,
          title: message_for(error)
        }
        formatted[:stack] = error.try(:backtrace) || [] if Rails.env.development?
        formatted
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
    raise 'Nope' unless date.match?(/^\d{4}-\d\d-\d\d(T\d\d:\d\d(:\d\d(\.\d+)?)?(Z|([+-]\d\d:?\d\d)))?$/)

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
  def where_in_range_param(collection, name, attribute = nil, &)
    return collection unless params[name]

    attribute = name if attribute.nil?
    range = parse_unbounded_range!(params[name], name, &)
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
