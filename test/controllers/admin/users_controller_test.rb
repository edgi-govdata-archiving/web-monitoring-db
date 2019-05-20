require 'test_helper'

class Admin::UsersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    sign_in users(:admin_user)
  end

  test 'view edit user page' do
    get edit_admin_user_path users(:alice)
    assert_response :success
  end

  test 'updating user sets database values and redirects to admin page' do
    user = users(:alice)
    permissions_payload = [User::VIEW_PERMISSION, User::MANAGE_USERS_PERMISSION, '0']

    put admin_user_path(user), params: { user: { permissions: permissions_payload } }

    assert_redirected_to admin_path
    assert_equal [User::VIEW_PERMISSION, User::MANAGE_USERS_PERMISSION], user.reload.permissions, 'User does not have correct permissions'
  end

  test 'non-admin users cannot access' do
    sign_in users(:alice)
    get edit_admin_user_path users(:alice)
    assert_response :redirect

    sign_out users(:alice)
    get edit_admin_user_path users(:alice)
    assert_response :redirect
  end
end
