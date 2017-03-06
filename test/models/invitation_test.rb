require 'test_helper'

class InvitationTest < ActiveSupport::TestCase
  test "invitations get a code when created" do
    invitation = Invitation.create
    assert invitation.code.present?
  end

  test "invitations validate e-mail addresses" do
    invitation = Invitation.create(email: 'test@example.com')
    assert invitation.valid?

    invitation = Invitation.create(email: 'blahblahblah')
    assert !invitation.valid?
  end

  test "invitations for existing users are invalid" do
    invitation = Invitation.create(email: users(:alice).email)
    assert !invitation.valid?
  end
end
