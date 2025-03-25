class ApplicationController < ActionController::Base
  include Pundit::Authorization
  include SameOriginSessionsConcern

  before_action :set_environment

  rescue_from Pundit::NotAuthorizedError, with: :not_authorized

  private

  def not_authorized
    return render(json: {}, status: :unauthorized) if request.format == :json

    if current_user.present?
      redirect_to root_path, alert: 'You are not authorized to view this page'
    else
      store_location_for :user, request.url
      redirect_to new_user_session_path, notice: 'You must sign in to access this page.'
    end
  end

  def set_environment
    @env = Rails.env
  end

  # Like `stale?` but takes a block to run if stale and resets all the
  # cache-related headers if the block raises.
  # See also: https://github.com/rails/rails/issues/54808
  def when_stale(object = nil, **)
    old_cache_control = response.cache_control.dup
    old_last_modified = response.last_modified

    yield if stale?(object, **)
  rescue StandardError => error
    # Response.cache_control has to be updated, not replaced.
    response.cache_control.clear.merge!(old_cache_control)
    # There is a constant for Last-Modified but not for this.
    response.delete_header('ETag')

    if old_last_modified
      response.last_modified = old_last_modified
    else
      response.delete_header(ActionDispatch::Http::Cache::Response::LAST_MODIFIED)
    end

    raise error
  end
end
