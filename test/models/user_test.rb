require 'test_helper'

class UserTest < ActiveSupport::TestCase
  test 'creating a user should send a confirmation email' do
    User.create(email: 'test@example.com', password: 'testpassword')
    confirmation_email = ActionMailer::Base.deliveries.last

    assert_equal(['test@example.com'], confirmation_email.to, 'E-mail was not sent to the correct address.')

    assert_match(
      /confirm/i,
      confirmation_email.subject.downcase,
      "'confirm' was not in the e-mail's subject line: `#{confirmation_email.subject}`"
    )
  end

  test 'confirming a user should destroy an attached invitation' do
    invitation = Invitation.create
    user = User.create(email: 'test@example.com', password: 'testpassword')
    user.invitation = invitation
    assert_equal(invitation, user.invitation, 'Invitation was not properly set on user')

    user.confirm
    assert_nil(user.invitation, 'The invitation is still on the user')
    assert_not(invitation.persisted?, 'The invitation is still in the DB')
  end

  test '#permissions validations' do
    user = users(:alice)
    assert user.valid?, 'Fixture should be valid'

    user.permissions = User::PERMISSIONS
    assert user.valid?, 'All permission strings should be valid permissions'

    user.permissions = []
    assert user.valid?, 'Empty permissions array should be valid'

    user.permissions = ['blargle']
    refute user.valid?, 'Invalid permission string should NOT be valid'

    user.permissions = nil
    refute user.valid?, 'Permission value should be an array'

    user.permissions = false
    refute user.valid?, 'Permission value should be an array'
  end

  test '#permission? describes whether use has permission' do
    user = users(:alice)
    refute user.permission?(User::MANAGE_USERS_PERMISSION), 'User should not be an admin'

    user.permissions << User::MANAGE_USERS_PERMISSION
    assert user.permission?(User::MANAGE_USERS_PERMISSION), 'User with manage_users should be admin'
  end

  test 'user has permission predicates' do
    user = users(:alice)
    refute user.can_manage_users?, 'User should not be able to manage users'

    user.permissions << User::MANAGE_USERS_PERMISSION
    assert user.can_manage_users?, 'User should be able to manage users'
  end
end
