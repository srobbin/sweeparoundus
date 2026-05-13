Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"], db: 1, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"], db: 1, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }
end

Sidekiq::Cron.configure do |config|
  config.cron_schedule_file = "config/cron.yml"
end
