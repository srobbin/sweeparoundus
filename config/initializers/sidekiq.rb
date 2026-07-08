# Retry a dropped/slow Redis connection with a short backoff before surfacing an
# error, so transient blips (Heroku Redis failover, network hiccups) self-heal
# instead of raising RedisClient::ReadTimeoutError in the Sidekiq fetch loop.
sidekiq_redis = {
  url: ENV["REDIS_URL"],
  db: 1,
  ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE },
  reconnect_attempts: [ 0.1, 0.5, 1.0 ]
}

Sidekiq.configure_server do |config|
  config.redis = sidekiq_redis
end

Sidekiq.configure_client do |config|
  config.redis = sidekiq_redis
end

Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = "config/cron.yml"
end
