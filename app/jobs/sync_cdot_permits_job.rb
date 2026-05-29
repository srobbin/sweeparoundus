class SyncCdotPermitsJob < ApplicationJob
  queue_as :default

  # With :polynomially_longer the 5 retries are spaced ~3s, 18s, 83s, 4.3m,
  # 10.5m apart — a total window of ~17 min, which stays comfortably under
  # the hour before CleanupStaleCdotPermitsJob runs (sync is scheduled for
  # 04:05, cleanup for 05:00 America/Chicago).
  retry_on StandardError, wait: :polynomially_longer, attempts: 6 do |_job, error|
    Rails.logger.error("[SyncCdotPermitsJob] All retries exhausted: #{error.class}: #{error.message}")
    Sentry.capture_exception(error)
  end

  def perform
    result = SyncCdotPermits.new.call
    Rails.logger.info("[SyncCdotPermitsJob] #{result}")
  end
end
