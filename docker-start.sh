#!/usr/bin/env bash
set -o errexit -o pipefail -o nounset

if [ "${RAILS_ENV}" == "production" ] || [ "${RACK_ENV}" == "production" ]
then
    bundle exec rake assets:precompile
fi

bundle exec rails server -b 0.0.0.0
