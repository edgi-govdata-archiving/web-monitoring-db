web: bundle exec rails server -p $PORT
worker: QUEUE=* VERBOSE=1 RESQUE_PRE_SHUTDOWN_TIMEOUT=10 RESQUE_TERM_TIMEOUT=10 bundle exec rake environment resque:work
