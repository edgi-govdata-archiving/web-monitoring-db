module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action { authorize :admin, :any? }
    protect_from_forgery with: :exception

    def edit
      @user = User.find(params[:id])
    end

    def update
      @user = User.find(params[:id])
      if @user.update(user_params)
        redirect_to admin_path, notice: "#{@user.email}’s account was updated"
      else
        render :edit
      end
    end

    private

    def user_params
      params.require(:user).permit(permissions: []).tap do |filtered_params|
        filtered_params[:permissions].delete('0') if filtered_params[:permissions]
      end
    end

    def require_admin!
      redirect_to '/' unless current_user.admin?
    end
  end
end
