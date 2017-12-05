# Auto-configuration of Redis connections based on REDIS_URL seems to have
# broken in either v4 or the Redis gem or v1.6 of redis-namespace. Manually fix
# up the configuration instead here.
if ENV['REDIS_URL']
  Rails.logger.debug('Configuring Redis URL')
  Resque.redis = Redis.new(url: ENV['REDIS_URL'])
end
