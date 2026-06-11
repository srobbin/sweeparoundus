require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Sweeparoundus
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    require_relative "../app/middleware/scanner_blocker"
    config.middleware.insert_before Rails::Rack::Logger, ScannerBlocker

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.eager_load_paths << Rails.root.join("extras")

    # UUIDs
    config.generators do |g|
      g.orm :active_record, primary_key_type: :uuid
    end

    # Redis cache
    config.cache_store = :redis_cache_store, { url: ENV["REDIS_URL"], db: 0, ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE } }

    # Sidekiq
    config.active_job.queue_adapter = :sidekiq

    # This app stores no image attachments and generates no variants, so skip
    # the image_processing gem (and its native libvips/ImageMagick dependency).
    # Disabling the variant processor also silences the boot-time warning Rails
    # logs when image_processing is absent.
    config.active_storage.variant_processor = :disabled

    # Time zone
    config.time_zone = ENV.fetch("DEFAULT_TIMEZONE") { "Central Time (US & Canada)" }

    # Host
    config.active_job.default_url_options = { host: ENV["SITE_URL"] }

    # Route exceptions through the app (see ErrorsController) so unrouted paths
    # and other 404s render the on-brand 404 page instead of the bare static
    # `public/404.html`. 422/500 are routed back to their existing static pages.
    config.exceptions_app = routes
  end
end
