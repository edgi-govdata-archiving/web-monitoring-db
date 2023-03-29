# Global options
GoodJob.active_record_parent_class = 'ApplicationRecord'

# Application options
Rails.application.configure do
  config.good_job.on_thread_error = ->(exception) { Sentry.capture_exception(exception) }
end
