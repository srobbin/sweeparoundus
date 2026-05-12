class SyncCdotPermitsJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform
    result = SyncCdotPermits.new.call
    Rails.logger.info("[SyncCdotPermitsJob] #{result}")
  end
end
