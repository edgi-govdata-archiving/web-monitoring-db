# frozen_string_literal: true

require 'test_helper'

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'should be able to view registration page' do
    get new_user_registration_path
    assert_response :success
  end
end
