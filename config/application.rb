require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WebpageVersionsDb
  class Application < Rails::Application
    config.load_defaults 6.0
    config.eager_load_paths << "#{Rails.root}/lib/api"

    config.active_job.queue_adapter = :resque

    # Ideally this should be served off a static store, but we don’t have much
    # in the way of asset needs since this is mainly an API.
    config.serve_static_assets = true

    # Support CORS requests for everything outside /admin
    # TODO: maybe better to have `/api/*` routes and turn CORS on only for those?
    config.middleware.insert_before 0, Rack::Cors do
      is_admin_url = lambda do |request|
        !request['PATH_INFO'].starts_with?('/admin')
      end

      allow do
        # Use this instead of `origins '*'` because we need to allow auth.
        # FIXME: We should come back and re-evaluate if we can change client
        # behavior to work with `origins '*'`
        origins /.*/
        resource '*',
          :headers => :any,
          :methods => [:get, :post, :options],
          :if => is_admin_url,
          :credentials => true
      end
    end

    # Optional caching via Redis
    if ENV['REDIS_CACHE_URL']
      config.cache_store = :redis_cache_store, {
        url: ENV.fetch('REDIS_CACHE_URL'),
        expires_in: 2.weeks.to_i,
        race_condition_ttl: 20.seconds,
        namespace: 'wmdbcache',
        error_handler: -> (method:, returning:, exception:) {
          # Rails cache fails silently without raising exceptions (which is
          # generally good), but we still want to know if it can't connect.
          Raven.capture_exception(exception, level: 'warning', tags: {
            method: method,
            returning: returning
          })
        }
      }
    end
  end
end
