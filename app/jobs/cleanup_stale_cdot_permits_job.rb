class CleanupStaleCdotPermitsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform
    result = CleanupStaleCdotPermits.new.call
    Rails.logger.info("[CleanupStaleCdotPermitsJob] #{result}")
  end
end
