require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sweeparoundus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 6.1

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # UUIDs
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # Redis cache
    config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"], db: 0 }

    # Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # Time zone
    config.time_zone = ENV.fetch("DEFAULT_TIMEZONE") { "Central Time (US & Canada)" }

    # Host
    config.active_job.default_url_options = { host: ENV["SITE_URL"] }
  end
end
