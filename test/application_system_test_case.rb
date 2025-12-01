# frozen_string_literal: true

require 'test_helper'

Capybara.save_path = Rails.root.join('tmp')

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  include ActiveJob::TestHelper
  include Capybara::Email::DSL

  driven_by :rack_test

  setup do
    @original_queue_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test

    @original_mailer_options = ActionMailer::Base.default_url_options
    ActionMailer::Base.default_url_options = { host: Capybara.server_host }

    clear_enqueued_jobs
    clear_performed_jobs
    clear_emails
  end

  teardown do
    clear_enqueued_jobs
    clear_performed_jobs
    clear_emails
    ActiveJob::Base.queue_adapter = @original_queue_adapter
    ActionMailer::Base.default_url_options = @original_mailer_options
  end
end
