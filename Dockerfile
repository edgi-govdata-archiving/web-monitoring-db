### BASE ENVIRONMENT STAGE ###
FROM ruby:4.0.9-slim AS base

LABEL org.opencontainers.image.title="web-monitoring-db" \
      org.opencontainers.image.description="API server for EDGI Web Monitoring" \
      org.opencontainers.image.authors="Environmental Data & Governance Initiative (EDGI)" \
      org.opencontainers.image.url="https://envirodatagov.org/" \
      org.opencontainers.image.source="https://github.com/edgi-govdata-archiving/web-monitoring-db" \
      org.opencontainers.image.licenses="GPL-3.0"

# Install system dependencies required for Rails to run.
# We also grab jemalloc here for better memory management.
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y \
      postgresql-client \
      libjemalloc2 \
    && ln -s /usr/lib/$(uname -m)-linux-gnu/libjemalloc.so.2 /usr/local/lib/libjemalloc.so \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development" \
    LD_PRELOAD="/usr/local/lib/libjemalloc.so"

# Configure the main working directory. This is the base directory used in any
# further RUN, COPY, and ENTRYPOINT commands.
RUN mkdir -p /app
WORKDIR /app


### BUILD IMAGE ###
FROM base AS build

# We need a bunch more system dependencies to build & install various Ruby
# and Node.js dependencies. These are only for the build stage and not needed
# at runtime.
RUN apt-get update -qq \
    && apt-get install --no-install-recommends -y \
      build-essential \
      git \
      libyaml-dev \
      libpq-dev \
      pkg-config \
      # node-gyp \
      # python-is-python3 \
      nodejs \
    && rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Copy the dependency info and install. This is separate from the rest of the \
# app source so Docker can cache it as a layer.
COPY Gemfile Gemfile.lock .ruby-version ./
RUN gem update --system \
    && bundle install \
    && rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git

# NOTE: Copying package.json/package-lock.json and installing would go here.

# Copy the main application.
COPY . ./

# Precompile Ruby code with bootsnap for faster startup.
RUN bundle exec bootsnap precompile --gemfile app/ lib/

# Not ideal, but set development for now to avoid a mess of non-precompilation
# environment configuration requirements.
# TODO: make assets:precompile work with RAILS_ENV=production here.
ENV RAILS_ENV="development"
RUN ./bin/rails assets:precompile \
    && rm -rf /rails/tmp/cache/assets/ /rails/node_modules/


### Production App Target ###
FROM base AS app

# Copy built gems, application, and artifacts.
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /app /app

WORKDIR /app

# Run the Rails server by default. depending on the container's role,
# you may want to run other commands (e.g. `bundle exec good_job start` for
# a job queue worker).
CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0"]
