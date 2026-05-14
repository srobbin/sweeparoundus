Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.send_default_pii = false # prevents sending IP, cookie, and request body
  config.release = ENV["HEROKU_BUILD_COMMIT"] || ENV["HEROKU_SLUG_COMMIT"]
  config.traces_sample_rate = 0.05
  config.profiles_sample_rate = 0.05
  config.excluded_exceptions += [
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound",
  ]

  config.enable_logs = true
  config.enabled_patches << :logger
end
