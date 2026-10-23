# frozen_string_literal: true

require 'test_helper'

class GoodJobTest < ActiveSupport::TestCase
  test 'has no pending migrations' do
    assert GoodJob.migrated?, 'GoodJob needs to install migrations; run `bin/rails g good_job:update`'
  end
end
