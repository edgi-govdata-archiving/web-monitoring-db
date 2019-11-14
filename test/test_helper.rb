ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../config/environment', __dir__)
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

  def assert_ordered_by(list, orderings, name: 'Items')
    sorted = list.sort do |a, b|
      result = 0
      orderings.each do |ordering|
        result = a[ordering[0]] <=> b[ordering[0]]
        unless result.zero?
          result *= -1 if ordering[1] && ordering[1].casecmp?('desc')
          break
        end
      end
      result
    end

    assert_equal(sorted, list, "#{name} were not in ordered by: #{orderings}")
  end

  def assert_any(list, operation, message = nil, description: nil)
    message ||= "Expected #{list} to have an item that #{description}" if description.present?
    assert_respond_to(list, :any?)
    assert(list.any? {|item| operation.call(item)}, message)
  end

  def assert_any_includes(list, value, message = nil)
    description = message.nil? ? "includes '#{value}'" : nil
    any_predicate = lambda { |item| item.include?(value) }
    assert_any(list, any_predicate, message, description: description)
  end
end
