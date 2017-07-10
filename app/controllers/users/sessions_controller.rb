class Users::SessionsController < Devise::SessionsController
  # Allow sign-in requests to get JSON, not just HTML
  respond_to :json

  # GET users/session -- determine whether a user is signed in or if credentials
  # or a token are valid (when using HTTP Auth).
  def validate_session
    if user_signed_in?
      render json: { user: current_user }
    else
      render status: :unauthorized, json: {
        status: 401,
        title: 'Unauthorized'
      }
    end
  end

  def create
    super do |user|
      # Devise doesn't give us a great way to customize the response, so
      # pre-empt the standard response and return early for JSON format
      if request.format == :json
        render json: {
          user: user,
          token: JwtTools::JwtCoder.encode(sub: "User:#{user.id}")
        }
        return
      end
    end
  end
end
