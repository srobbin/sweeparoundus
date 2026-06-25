Sentry.init do |config|
  config.dsn = ENV["SENTRY_DSN"]
  config.enabled_environments = %w[production]
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.send_default_pii = false # prevents sending IP, cookie, and request body
  config.release = ENV["HEROKU_BUILD_COMMIT"] || ENV["HEROKU_SLUG_COMMIT"]
  config.traces_sample_rate = 0.05
  config.profiles_sample_rate = 0.05
  config.excluded_exceptions += [
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound"
  ]

  config.enable_logs = true
  config.enabled_patches << :logger

  # The `:logger` patch sends Rails request-completion logs to Sentry. Drop
  # expected scanner/bot noise: 404s and JSON API 422s for missing/invalid params.
  # Keep other logs, including user-facing 422 form validation outside `/api/`.
  config.before_send_log = lambda do |log|
    next log unless log.origin == "auto.log.rails.log_subscriber"

    status = (log.attributes[:status] || log.attributes["status"]).to_i
    path = (log.attributes[:path] || log.attributes["path"]).to_s

    next nil if status == 404
    next nil if status == 422 && path.start_with?("/api/")

    log
  end
end
