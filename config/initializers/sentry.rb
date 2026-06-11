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

  # The `:logger` patch ships every request-completion log to Sentry Logs,
  # so our 404 handling sends a `warn` log for each not-found request. Those
  # 404s are expected noise (mistyped URLs, scanners, prefetchers), so drop
  # the Rails subscriber's 404 logs and pass everything else through.
  config.before_send_log = lambda do |log|
    status = (log.attributes[:status] || log.attributes["status"]).to_i

    if log.origin == "auto.log.rails.log_subscriber" && status == 404
      nil
    else
      log
    end
  end
end
