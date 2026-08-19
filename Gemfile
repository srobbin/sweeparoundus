source "https://rubygems.org"

ruby "4.0.6"

gem "rails", "~> 8.1"

# Core
gem "bootsnap", "~> 1.24", require: false
gem "pg", "~> 1.6"
gem "puma", "~> 8.0"
gem "redis", "~> 5.4"

# Frontend / Assets
gem "dartsass-rails", "~> 0.5.1"
gem "importmap-rails", "~> 2.2"
gem "rails_icons", "~> 1.9"
gem "sassc-embedded", "~> 1.80"
gem "sprockets-rails", "~> 3.5"
gem "stimulus-rails", "~> 1.3"
gem "tailwindcss-rails", "~> 4.6"
gem "turbo-rails", "~> 2.0"

# Authentication / Authorization
gem "devise", "~> 5.0"
gem "jwt", "~> 3.2"
gem "pundit", "~> 2.5"

# Background Jobs
gem "sidekiq", "~> 8.1"
gem "sidekiq-cron", "~> 2.0"

# Database / Geo
gem "activerecord-postgis-adapter", "~> 11.1"
gem "friendly_id", "~> 5.7"
gem "rgeo-geojson", "~> 2.2"

# Admin / Views
gem "activeadmin", "~> 3.5"

# Monitoring / Performance
gem "scout_apm", "~> 6.2"
gem "scout_apm_logging", "~> 2.1"
gem "sentry-rails", "~> 6.6"
gem "sentry-ruby", "~> 6.6"
gem "sentry-sidekiq", "~> 6.6"
gem "stackprof", "~> 0.2"

# Email / Notifications
gem "icalendar", "~> 2.12"
gem "sendgrid-ruby", "~> 6.7"

# GitHub API (CheckSweepingDataUpdatesJob opens data-update PRs).
# faraday-retry enables Octokit's optional retry middleware (and silences its
# load-time warning); without it Faraday v2 logs that the middleware is absent.
gem "octokit", "~> 10.0"
gem "faraday-retry", "~> 2.3"

# Security / Middleware
gem "rack-attack", "~> 6.7"

# Ruby stdlib extractions (removed in Ruby 4.0)
gem "cgi", "~> 0.5"
gem "connection_pool", "~> 3.0"
gem "observer", "~> 0.1"
gem "ostruct", "~> 0.6"

# Platform-specific
gem "tzinfo-data", platforms: [ :windows, :jruby ]

group :development, :test do
  gem "debug", "~> 1.11", platforms: [ :mri, :windows ]
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.8"
  gem "pg_query", "~> 6.2"
  gem "prosopite", "~> 2.2"
  gem "rspec-rails", "~> 8.0"
end

group :development do
  gem "foreman", "~> 0.90.0"
  gem "letter_opener_web", "~> 3.0"
  gem "listen", "~> 3.10"
  gem "rubocop-rails-omakase", require: false
  gem "web-console", "~> 4.3"
end

group :test do
  gem "webmock", "~> 3.23"
end
