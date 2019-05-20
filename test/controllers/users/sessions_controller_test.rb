require 'test_helper'

class Users::SessionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'active session returns user object' do
    sign_in users(:alice)

    get users_session_path

    assert_response :success
    body = JSON.parse @response.body
    assert_equal  ["view", "annotate", "import"], body['user']['permissions'], "User JSON contains permissions"
  end
end
