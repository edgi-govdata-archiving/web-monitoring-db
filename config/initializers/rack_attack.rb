# Optionally block requests missing a special header. Ideally this would
# be done at the load balancer instead, but that's not always possible.
secret_access_key_headers = ENV.fetch('REQUIRE_SECRET_ACCESS_KEY_HEADER', '').split(',')
if secret_access_key_headers.present?
  Rack::Attack.blocklist('secret_header') do |req|
    secret_access_key_headers.exclude?(req.get_header('HTTP_X_SECRET_ACCESS_KEY'))
  end
end
