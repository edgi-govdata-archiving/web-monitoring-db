class Api::V0::ApiController < ApplicationController
  include PagingConcern
  before_action :require_authentication!, only: [:create]

  rescue_from StandardError, with: :render_errors unless Rails.env.development?
  rescue_from Api::NotImplementedError, with: :render_errors
  rescue_from Api::InputError, with: :render_errors

  rescue_from ActiveModel::ValidationError do |error|
    render_errors(error.model.errors.full_messages, 400)
  end

  rescue_from ActiveModel::ValidationError do |error|
    render_errors(error, 404)
  end


  protected

  def paging_url_format
    ''
  end

  # This is different from Devise's authenticate_user! -- it does not redirect.
  def require_authentication!
    unless user_signed_in?
      render_errors('You must be logged in to perform this action.', 401)
    end
  end

  # Render an error or errors as a proper API response
  def render_errors(errors, status_code = nil)
    errors = [errors] unless errors.is_a?(Array)
    status_code ||= errors.first.try(:status_code) || 500

    render status: status_code, json: {
      errors: errors.collect do |error|
        {
          status: status_code,
          title: error.try(:message) || error.try(:[], :message) || error.to_s
        }
      end
    }
  end
end
