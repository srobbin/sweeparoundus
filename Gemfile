source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.4.7"

gem "rails", "~> 7.2.3.1"
gem "pg", "~> 1.1"
gem "jbuilder", "~> 2.7"

gem "activeadmin", "~> 3.5"
gem "activerecord-postgis-adapter", "~> 10.0"
gem "bootsnap", "~> 1.18", require: false
gem "dartsass-rails", "~> 0.5.1"
gem "devise", "~> 5.0"
gem "draper", "~> 4.0"
gem "friendly_id", "~> 5.4"
gem "importmap-rails"
gem "icalendar", "~> 2.12"
gem "jwt", "~> 2.2"
gem "sendgrid-ruby", "~> 6.7"
gem "puma", "~> 6.6.0"
gem "pundit", "~> 2.1"
gem "rack-attack", "~> 6.7"
gem 'redis', '~> 5.0', '>= 5.0.8'
gem "rgeo-geojson", "~> 2.2"
gem "sassc", "~> 2.4"
gem 'sidekiq', '~> 7.2'
gem "sidekiq-cron", "~> 1.11"
gem "sprockets-rails", "~> 3.5"
gem "tailwindcss-rails", "~> 0.3"
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

gem "stimulus-rails", "~> 1.3"
gem "turbo-rails", "~> 2.0"

gem "connection_pool", "~> 2.4"
gem "observer", "~> 0.1"
gem "ostruct", "~> 0.6"

group :development, :test do
  gem "byebug", platforms: [:mri, :mingw, :x64_mingw]
  gem "factory_bot_rails", "~> 6.2"
  gem "faker", "~> 3.2"
  gem "rspec-rails", "~> 7.1"
end

group :development do
  gem "foreman", "~> 0.90.0"
  gem "letter_opener", "~> 1.10"
  gem "listen", "~> 3.9"
  gem "web-console", ">= 4.1.0"
  # gem "rack-mini-profiler", "~> 2.0"
end

group :test do
  gem "capybara", ">= 3.26"
  gem "selenium-webdriver"
  gem "webmock", "~> 3.23"
  gem "webdrivers"
end
