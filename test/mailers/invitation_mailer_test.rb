require 'test_helper'

class InvitationMailerTest < ActionMailer::TestCase
  def test_send_invitation_email
    invitation = Invitation.create(email: "test@email.com")
    invitation.update_attributes(code: "eff7df8ccc0cd0256619")
    email = InvitationMailer.invitation_email(invitation)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal "Welcome to EDGI web monitoring", email.subject
    assert_equal [ENV.fetch('MAIL_SENDER', 'web-monitoring-db@envirodatagov.org')], email.from
    assert_equal ["test@email.com"], email.to
    assert_match /http:\/\/web-monitoring-db.test\/users\/sign_up\?invitation=\w+/, email.html_part.body.to_s
    assert_match /http:\/\/web-monitoring-db.test\/users\/sign_up\?invitation=\w+/, email.text_part.body.to_s
  end
end
