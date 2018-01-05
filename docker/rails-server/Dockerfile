FROM envirodgi/db-generic
MAINTAINER enviroDGI@gmail.com

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# Pre-compile static assets.
RUN bundle exec rake assets:precompile

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
