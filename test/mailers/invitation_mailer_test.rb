require 'test_helper'

class InvitationMailerTest < ActionMailer::TestCase
  # Make it possible to generate URLs. In mailer tests, URL helpers are missing
  # the action_mailer URL configuration.
  # NOTE: this is handled automatically in RSpec
  include Rails.application.routes.url_helpers

  def mail_url(route, options = nil)
    url_for([
              route,
              Rails.application.config.action_mailer.default_url_options.merge(options)
            ])
  end

  def test_send_invitation_email
    invitation = Invitation.create(email: 'test@email.com')
    invitation.update(code: 'eff7df8ccc0cd0256619')
    email = InvitationMailer.invitation_email(invitation)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal 'Welcome to EDGI web monitoring', email.subject
    assert_equal [ENV.fetch('MAIL_SENDER', 'web-monitoring-db@envirodatagov.org')], email.from
    assert_equal ['test@email.com'], email.to

    invite_url = mail_url(:new_user_registration, invitation: invitation.code)
    assert_includes email.html_part.body.to_s, invite_url
    assert_includes email.text_part.body.to_s, invite_url
  end
end
