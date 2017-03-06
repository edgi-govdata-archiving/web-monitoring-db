class InvitationMailer < ApplicationMailer
  def invitation_email(invitation)
    @invitation = invitation
    @url = new_user_registration_url(invitation: @invitation.code)
    mail(from: Devise.mailer_sender, to: @invitation.email, subject: 'Welcome to EDGI web monitoring')
  end
end
