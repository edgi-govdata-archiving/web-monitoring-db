require 'test_helper'

class GoodJobTest < ActiveSupport::TestCase
  test 'has no pending migrations' do
    assert GoodJob.migrated?
  end
end
