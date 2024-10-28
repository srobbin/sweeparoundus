source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

gem "rails", "~> 7.1.4.2"
gem "pg", "~> 1.1"
gem "jbuilder", "~> 2.7"

gem "activeadmin", "~> 3.2"
gem "activerecord-postgis-adapter", "~> 9.0.1"
gem "bootsnap", "~> 1.17", require: false
gem "dartsass-rails", "~> 0.5.0"
gem "devise", "~> 4.9"
gem "draper", "~> 4.0"
gem "friendly_id", "~> 5.4"
gem "hotwire-rails", "~> 0.1.3"
gem "icalendar", "~> 2.10"
gem "jwt", "~> 2.2"
gem "mailgun-ruby", "~> 1.2"
gem "puma", "~> 6.4.3"
gem "pundit", "~> 2.1"
gem 'redis', '~> 5.0', '>= 5.0.8'
gem "rgeo-geojson", "2.0.0"
gem "sassc", "~> 2.4"
gem 'sidekiq', '~> 7.1', '>= 7.1.2'
gem "sidekiq-cron", "~> 1.11"
gem "sprockets-rails", "~> 3.4"
gem "tailwindcss-rails", "~> 0.3"
gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]

# Avoid breaking changes
gem "stimulus-rails", "0.2.4"
gem "turbo-rails", "0.5.12"

group :development, :test do
  gem "byebug", platforms: [:mri, :mingw, :x64_mingw]
  gem "factory_bot_rails", "~> 6.2"
  gem "faker", "~> 3.2"
  gem "rspec-rails", "~> 6.0"
end

group :development do
  gem "foreman", "~> 0.87.2"
  gem "letter_opener", "~> 1.8"
  gem "listen", "~> 3.3"
  gem "web-console", ">= 4.1.0"
  # gem "rack-mini-profiler", "~> 2.0"
end

group :test do
  gem "capybara", ">= 3.26"
  gem "selenium-webdriver"
  gem "webmock", "~> 3.23"
  gem "webdrivers"
end
