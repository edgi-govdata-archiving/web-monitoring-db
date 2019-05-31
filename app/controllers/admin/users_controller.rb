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
        # The permissions field in the form is rendered as a list of checkboxes.
        # A hidden form field with value "0" is inserted to ensure that browsers always
        # POST a value from the form for permissions even when no permissions are granted.
        # Any hidden values must be removed so that there is a clean array of permissions.
        #
        # https://api.rubyonrails.org/classes/ActionView/Helpers/FormHelper.html#method-i-check_box
        filtered_params[:permissions].try(:delete, '0')
      end
    end
  end
end
