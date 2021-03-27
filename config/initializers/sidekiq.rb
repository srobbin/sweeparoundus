Sidekiq.configure_server do |config|
  config.redis = { url: ENV["REDIS_URL"], db: 1 }

  # Cron
  schedule_file = "config/cron.yml"
  if File.exist?(schedule_file)
    jobs = YAML.load_file(schedule_file)
    Sidekiq::Cron::Job.load_from_hash(jobs) if jobs
  end
end

Sidekiq.configure_client do |config|
  config.redis = { url: ENV["REDIS_URL"], db: 1 }
end
