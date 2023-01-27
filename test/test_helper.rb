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

  def assert_ordered_by(list, orderings, name: 'Items', case_sensitive: false)
    sorted = list.sort do |a, b|
      result = 0
      orderings.each do |ordering|
        result = if a[ordering[0]].is_a?(String) && !case_sensitive
                   a[ordering[0]].casecmp(b[ordering[0]])
                 else
                   a[ordering[0]] <=> b[ordering[0]]
                 end
        unless result.zero?
          result *= -1 if ordering[1] && ordering[1].casecmp?('desc')
          break
        end
      end
      result
    end

    assert_equal(sorted, list, "#{name} were not in order by: #{orderings}")
  end

  def assert_any(list, predicate, message = nil)
    message ||= "Expected #{list} to have a matching item"
    assert_respond_to(list, :any?)
    assert(list.any? {|item| predicate.call(item)}, message)
  end

  def assert_any_includes(list, value, message = nil)
    message ||= "Expected #{list} to have an item that includes '#{value}'"
    assert_any(list, ->(item) { item.include?(value) }, message)
  end

  def with_rails_configuration(key, value, &block)
    original =  Rails.configuration.send(key)
    Rails.configuration.send("#{key}=", value)
    block.call
  ensure
    Rails.configuration.send("#{key}=", original)
  end
end
