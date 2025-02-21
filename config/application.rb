require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WebpageVersionsDb
  class Application < Rails::Application
    config.load_defaults 8.0
    # FIXME: this needs cleanup; this stuff should probably move to app/lib for autoloading.
    #  (We can also use `config.autoload_lib(ignore: %w(assets tasks))` or similar, but I
    #  think segregating lib and app/lib on autoloading is better.)
    config.eager_load_paths << "#{Rails.root}/lib/api"

    # Re-instate secrets for simpler management of `secret_key_base`. We currently use other methods for managing
    # secrets in production, so it doesn't make a whole lot of sense to migrate to credentials (which replaces secrets)
    # just for secret_key_base (which then requires more complicated key management work).
    # TODO: consider dropping this entirely in favor of better .env file management (and still no Rails credentials).
    config.secrets = config_for(:secrets)
    config.secret_key_base = config.secrets[:secret_key_base]
    def secrets
      config.secrets
    end

    config.active_job.queue_adapter = :good_job

    # Deliver mail on the `mailers` queue. This is the old default from
    # Rails 6.0 and earlier; I think it's useful. Keeping it also lets us
    # maintain existing server deployment configurations for jobs.
    Rails.application.config.action_mailer.deliver_later_queue_name = :mailers

    config.middleware.use Rack::Deflater
    config.middleware.use Rack::Brotli

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
          Sentry.capture_exception(exception, level: 'warning', tags: {
            method: method,
            returning: returning
          })
        }
      }
    end

    config.allow_public_view = ActiveModel::Type::Boolean.new.cast(
      ENV.fetch('ALLOW_PUBLIC_VIEW', 'true')
    ).present?

    config.read_only = ActiveModel::Type::Boolean.new.cast(
      ENV.fetch('API_READ_ONLY', 'true')
    ).present?
  end
end
