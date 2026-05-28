source "https://rubygems.org"

ruby "3.4.7"

gem "rails", "~> 7.2.3.1"

# Core
gem "bootsnap", "~> 1.18", require: false
gem "pg", "~> 1.6"
gem "puma", "~> 8.0"
gem "redis", "~> 5.4"

# Frontend / Assets
gem "dartsass-rails", "~> 0.5.1"
gem "importmap-rails", "~> 2.2"
gem "rails_icons", "~> 1.8"
gem "sassc-embedded", "~> 1.80"
gem "sprockets-rails", "~> 3.5"
gem "stimulus-rails", "~> 1.3"
gem "tailwindcss-rails", "~> 2.7"
gem "turbo-rails", "~> 2.0"

# Authentication / Authorization
gem "devise", "~> 5.0"
gem "jwt", "~> 3.2"
gem "pundit", "~> 2.1"

# Background Jobs
gem "sidekiq", "~> 7.3"
gem "sidekiq-cron", "~> 2.0"

# Database / Geo
gem "activerecord-postgis-adapter", "~> 10.0"
gem "friendly_id", "~> 5.7"
gem "rgeo-geojson", "~> 2.2"

# Admin / Views
gem "activeadmin", "~> 3.5"

# Monitoring / Performance
gem "scout_apm", "~> 6.2"
gem "scout_apm_logging", "~> 2.1"
gem "sentry-rails", "~> 6.5"
gem "sentry-ruby", "~> 6.5"
gem "sentry-sidekiq", "~> 6.5"
gem "stackprof", "~> 0.2"

# Email / Notifications
gem "icalendar", "~> 2.12"
gem "sendgrid-ruby", "~> 6.7"

# Security / Middleware
gem "rack-attack", "~> 6.7"

# Ruby stdlib extractions (required in Ruby 3.4+)
gem "connection_pool", "~> 2.4"
gem "observer", "~> 0.1"
gem "ostruct", "~> 0.6"

# Platform-specific
gem "tzinfo-data", platforms: [ :mingw, :mswin, :x64_mingw, :jruby ]

group :development, :test do
  gem "debug", "~> 1.11", platforms: [ :mri, :mingw, :x64_mingw ]
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.2"
  gem "pg_query", "~> 6.2"
  gem "prosopite", "~> 2.2"
  gem "rspec-rails", "~> 8.0"
end

group :development do
  gem "foreman", "~> 0.90.0"
  gem "letter_opener_web", "~> 3.0"
  gem "listen", "~> 3.10"
  gem "rubocop-rails-omakase", require: false
  gem "web-console", "~> 4.2"
end

group :test do
  gem "webmock", "~> 3.23"
end
