ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rails/test_help'
require 'webmock/minitest'

class ActiveSupport::TestCase
  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Add more helper methods to be used by all tests here...
  def assert_ordered(list, reverse: false, name: 'Items')
    sorted = list.sort
    sorted = sorted.reverse if reverse
    assert_equal(sorted, list, "#{name} were not in order: #{list}")
  end
end
