class ApplicationController < ActionController::Base
  include Pundit
  include SameOriginSessionsConcern

  before_action :set_environment

  rescue_from Pundit::NotAuthorizedError, with: :not_authorized

  private

  def not_authorized
    return render(json: {}, status: :unauthorized) if request.xhr?

    if current_user.present?
      redirect_to root_path, alert: "You are not authorized to view this page"
    else
      store_location_for :user, request.url
      redirect_to new_user_session_path, notice: 'You must sign in to access this page.'
    end
  end

  def set_environment
    @env = Rails.env
  end
end
