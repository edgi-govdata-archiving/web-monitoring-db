# This Dockerfile uses a multi-stage build.
# https://docs.docker.com/engine/userguide/eng-image/multistage-build

### BASE ENVIRONMENT STAGE ###
FROM ruby:2.5.1-slim as base
MAINTAINER enviroDGI@gmail.com

# Install apt based dependencies required to run Rails as
# well as RubyGems. As the Ruby image itself is based on a
# Debian image, we use apt-get to install those.
RUN apt-get update && apt-get install -y \
    build-essential \
    nodejs \
    libpq-dev

# Configure the main working directory. This is the base
# directory used in any further RUN, COPY, and ENTRYPOINT
# commands.
RUN mkdir -p /app
WORKDIR /app

# Copy the Gemfile as well as the Gemfile.lock and install
# the RubyGems. This is a separate step so the dependencies
# will be cached unless changes to one of those two files
# are made.
COPY Gemfile Gemfile.lock ./
RUN gem install bundler && bundle install --jobs 20 --retry 5

# Copy the main application.
COPY . ./


### IMPORT WORKER TARGET ###
FROM base as import-worker
MAINTAINER enviroDGI@gmail.com
WORKDIR /app

ENV QUEUE=*
ENV VERBOSE=1

CMD ["bundle", "exec", "rake", "environment", "resque:work"]


### RAILS SERVER TARGET ###
FROM base as rails-server
MAINTAINER enviroDGI@gmail.com
WORKDIR /app

# Expose port 3000 to the Docker host, so we can access it
# from the outside.
EXPOSE 3000

# Pre-compile static assets.
RUN bundle exec rake assets:precompile

# The main command to run when the container starts. Also
# tell the Rails dev server to bind to all interfaces by
# default.
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
