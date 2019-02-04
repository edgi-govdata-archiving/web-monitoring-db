require 'test_helper'

class AdminControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  def setup
    sign_in users(:admin_user)
  end

  test 'promote user to admin format JSON' do
    user = User.create(email: "test@email.com", password: "password", password_confirmation: "password")

    put '/admin/promote_user_to_admin', params: { id: user.id, format: "json" }

    user.reload
    parsed_response = JSON.parse(response.body)
    assert_equal 'application/json', @response.content_type
    assert parsed_response["data"]["success"]
    assert user.admin?
  end

  test 'demote user from admin format JSON' do
    user = User.create(email: "test@email.com", password: "password", password_confirmation: "password", admin: true)

    put '/admin/demote_user_from_admin', params: { id: user.id, format: "json" }

    user.reload
    parsed_response = JSON.parse(response.body)
    assert_response :success
    assert_equal 'application/json', @response.content_type
    assert parsed_response["data"]["success"]
    refute user.admin?
  end

  test 'promote user to admin format HTML' do
    user = User.create(email: "test@email.com", password: "password", password_confirmation: "password")

    put '/admin/promote_user_to_admin', params: { id: user.id }

    user.reload
    assert_redirected_to admin_path
    assert user.admin?
  end

  test 'demote user from admin format HTML' do
    user = User.create(email: "test@email.com", password: "password", password_confirmation: "password", admin: true)

    put '/admin/demote_user_from_admin', params: { id: user.id }

    user.reload
    assert_redirected_to admin_path
    refute user.admin?
  end
end
