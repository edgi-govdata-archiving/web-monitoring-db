require "test_helper"

Capybara::save_path = Rails.root.join('tmp')

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper
  include Capybara::Email::DSL

  driven_by :rack_test

  def setup
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    clear_enqueued_jobs
    clear_performed_jobs
    clear_emails
  end

  def teardown
    clear_enqueued_jobs
    clear_performed_jobs
    clear_emails
    ActiveJob::Base.queue_adapter = @original_queue_adapter
  end
end
