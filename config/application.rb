require_relative 'boot'

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module WebpageVersionsDb
  class Application < Rails::Application
    # Support CORS requests for everything outside /admin
    # TODO: maybe better to have `/api/*` routes and turn CORS on only for those?
    config.middleware.insert_before 0, Rack::Cors do
      is_admin_url = lambda do |request|
        !request['PATH_INFO'].starts_with?('/admin')
      end

      allow do
        origins '*'
        resource '*', :headers => :any, :methods => [:get, :post, :options], :if => is_admin_url
      end
    end
  end
end
