Rails.application.configure do
  if ENV['REDIS_CACHE_URL']
    config.cache_store = :readthis_store, {
      expires_in: 2.weeks.to_i,
      namespace: 'wmdbcache',
      redis: { url: ENV.fetch('REDIS_CACHE_URL'), driver: :hiredis }
    }
  end
end
