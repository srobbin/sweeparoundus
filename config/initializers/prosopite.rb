unless Rails.env.production?
  require "prosopite/middleware/rack"
  Rails.configuration.middleware.use(Prosopite::Middleware::Rack)

  # ActiveAdmin scope tabs each run a COUNT(*) with the same fingerprint;
  # these are not N+1 loops.
  Prosopite.ignore_queries = [ /SELECT COUNT\(\*\) FROM "alerts" WHERE "alerts"\."confirmed"/ ]
end
