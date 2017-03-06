require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test "creating a user should send a confirmation email" do
    user = User.create(email: 'test@example.com', password: 'testpassword')
    confirmation_email = ActionMailer::Base.deliveries.last

    assert_equal ['test@example.com'], confirmation_email.to, "E-mail was not sent to the correct address."

    assert_match /confirm/i, confirmation_email.subject.downcase,
      "'confirm' was not in the e-mail's subject line: `#{confirmation_email.subject}`"
  end

  test "confirming a user should destroy an attached invitation" do
    invitation = Invitation.create
    user = User.create(email: 'test@example.com', password: 'testpassword')
    user.invitation = invitation
    assert_equal invitation, user.invitation, "Invitation was not properly set on user"

    user.confirm
    assert_nil user.invitation, "The invitation is still on the user"
    assert_not invitation.persisted?, "The invitation is still in the DB"
  end
end
