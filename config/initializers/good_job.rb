# Global options
GoodJob.active_record_parent_class = 'ApplicationRecord'

# Application options
Rails.application.configure do
  config.good_job.on_thread_error = ->(exception) { Sentry.capture_exception(exception) }

  # Not yet documented, but *should* be good for performance.
  # Added in v4.15.0 (https://github.com/bensheldon/good_job/pull/1645)
  config.good_job.dequeue_query_sort = :scheduled_at
end
