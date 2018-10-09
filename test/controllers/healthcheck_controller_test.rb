require 'test_helper'
require 'minitest/mock'

class Api::V0::DiffControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'healthcheck responds with success' do
    get '/healthcheck'
    assert_response :success
    assert_equal 'application/json', @response.content_type
  end
end
