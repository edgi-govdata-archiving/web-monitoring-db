# frozen_string_literal: true

require 'test_helper'

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'active session returns user object' do
    sign_in users(:alice)

    get users_session_path

    assert_response :success
    body = JSON.parse @response.body
    assert_equal ['view', 'annotate', 'import'], body['user']['permissions'], 'User JSON contains permissions'
  end

  test 'handles null bytes in new session get' do
    get(new_user_session_path, params: {
      user: {
        email: users(:alice).email,
        password: "something\x00bad"
      }
    })
    assert_response :success
  end

  test 'handles null bytes in new session post' do
    post new_user_session_path, params: {
      user: {
        email: users(:alice).email,
        password: "something\x00bad"
      }
    }
    assert_response :unprocessable_content
  end
end
