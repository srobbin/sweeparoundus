source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.2.2"

gem "rails", "~> 6.1.7.5"
gem "pg", "~> 1.1"
gem "puma", "~> 5.6.7"
gem "sass-rails", ">= 6"
gem "jbuilder", "~> 2.7"
gem "bootsnap", ">= 1.4.4", require: false

gem "activeadmin", "~> 2.9"
gem "activerecord-postgis-adapter", "~> 7.0"
gem "devise", "~> 4.7"
gem "draper", "~> 4.0"
gem "friendly_id", "~> 5.4"
gem "hotwire-rails", "~> 0.1.3"
gem "icalendar", "~> 2.7"
gem "jwt", "~> 2.2"
gem "mailgun-ruby", "~> 1.2"
gem "pundit", "~> 2.1"
gem 'redis', '~> 5.0', '>= 5.0.8'
gem "rgeo-geojson", "2.0.0"
gem 'sidekiq', '~> 7.1', '>= 7.1.2'
gem "sidekiq-cron", "~> 1.11"
gem "tailwindcss-rails", "~> 0.3"

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
  gem "letter_opener", "~> 1.7"
  gem "listen", "~> 3.3"
  gem "spring", "~> 2.1"
  gem "web-console", ">= 4.1.0"
  # gem "rack-mini-profiler", "~> 2.0"
end

group :test do
  gem "capybara", ">= 3.26"
  gem "selenium-webdriver"
  gem "webdrivers"
end

gem "tzinfo-data", platforms: [:mingw, :mswin, :x64_mingw, :jruby]
