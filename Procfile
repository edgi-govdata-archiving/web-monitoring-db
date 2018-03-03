release: bundle exec rake db:migrate
web: bundle exec rails server -p $PORT
worker: QUEUE=* VERBOSE=1 bundle exec rake environment resque:work
