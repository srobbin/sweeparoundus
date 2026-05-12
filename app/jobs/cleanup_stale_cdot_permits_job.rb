class CleanupStaleCdotPermitsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3 do |_job, error|
    Rails.logger.error("[CleanupStaleCdotPermitsJob] All retries exhausted: #{error.class}: #{error.message}")
    Sentry.capture_exception(error)
  end

  def perform
    result = CleanupStaleCdotPermits.new.call
    Rails.logger.info("[CleanupStaleCdotPermitsJob] #{result}")
  end
end
