class AdminController < ApplicationController
  protect_from_forgery with: :exception

  before_action :authenticate_user!
  before_action :require_admin!

  def index
    @users = User.all
    @invitations = Invitation.all
    @invitation ||= Invitation.new
  end

  def invite
    invitation_email = params[:invitation][:email]
    @invitation = Invitation.create(issuer: current_user, email: invitation_email)

    @invitation.send_email if @invitation.persisted?

    respond_to do |format|
      format.html do
        if @invitation.valid?
          redirect_to admin_path
        else
          index
          render :index
        end
      end

      format.json do
        if @invitation.valid?
          render json: { data: @invitation }
        else
          render json: { errors: @invitation.errors }
        end
      end
    end
  end

  def cancel_invitation
    @invitation = Invitation.find(params[:id])
    @invitation.destroy

    respond_to do |format|
      format.html do
        email_addendum = @invitation.email.present? ? " (sent to #{@invitation.email})" : ''
        message = "The invitation code “#{@invitation.code}”#{email_addendum} was canceled."
        redirect_to admin_path, notice: message
      end

      format.json do
        render json: { data: { success: true, code: @invitation.code } }
      end
    end
  end

  def destroy_user
    @user = User.find(params[:id])

    @user.destroy unless @user.id == current_user.id

    respond_to do |format|
      format.html do
        if @user.persisted?
          redirect_to admin_path, alert: 'You can not delete your own account'
        else
          redirect_to admin_path, notice: "#{@user.email}’s account was deleted"
        end
      end

      format.json do
        render json: { data: { success: !@user.persisted? } }
      end
    end
  end

  def promote_user_to_admin
    @user = User.find(params[:id])

    @user.update_attributes!(admin: true)

    respond_to do |format|
      format.html do
        if !@user.admin?
          redirect_to admin_path, alert: 'There was an error while promoting the user to admin'
        else
          redirect_to admin_path, notice: "#{@user.email} has been promoted to admin"
        end
      end

      format.json do
        render json: { data: { success: @user.admin? } }
      end
    end
  end

  def demote_user_from_admin
    @user = User.find(params[:id])

    @user.update_attributes!(admin: false)

    respond_to do |format|
      format.html do
        if @user.admin?
          redirect_to admin_path, alert: 'There was an error while demoting the user from admin'
        else
          redirect_to admin_path, notice: "#{@user.email} has been demoted from admin"
        end
      end

      format.json do
        render json: { data: { success: !@user.admin? } }
      end
    end
  end


  protected

  def require_admin!
    redirect_to '/' unless current_user.admin?
  end
end
