class Users::SessionsController < Devise::SessionsController
  # Allow sign-in requests to get JSON, not just HTML
  respond_to :json

  # GET users/session -- determine whether a user is signed in or if credentials
  # or a token are valid (when using HTTP Auth).
  def validate_session
    if user_signed_in?
      render json: current_user
    else
      render status: :unauthorized, json: {
        status: 401,
        title: 'Unauthorized'
      }
    end
  end
end
