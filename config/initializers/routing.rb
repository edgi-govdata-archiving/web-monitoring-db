Rails.application.configure do
  # Copy URL options from action_mailer config (which may be set differently per environment).
  Rails.application.routes.default_url_options.merge!(config.action_mailer.default_url_options.clone)
end
