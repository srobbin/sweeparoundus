require "digest"

class ConfirmationEmailRateLimiter
  LIMIT = 4
  PERIOD = 1.hour
  COOLDOWN = 60.seconds

  # Conservative upper bound: cache counters do not expose their remaining TTL.
  attr_reader :retry_after

  def initialize(email)
    @digest = Digest::SHA256.hexdigest(email.to_s.strip.downcase)
  end

  def allowed?
    @unavailable = false
    @retry_after = COOLDOWN.to_i
    store = Rack::Attack.cache.store
    # Atomic reservations across processes; fail closed if the cache is unavailable.
    cooldown = store.increment("confirmation-email/cooldown/#{@digest}", 1, expires_in: COOLDOWN)
    return cache_unavailable if cooldown.nil?
    return false unless cooldown == 1

    count = store.increment("confirmation-email/hour/#{@digest}", 1, expires_in: PERIOD)
    return cache_unavailable if count.nil?
    @retry_after = PERIOD.to_i unless count.present? && count <= LIMIT
    count.present? && count <= LIMIT
  rescue Redis::BaseError, ConnectionPool::TimeoutError => e
    cache_unavailable(e)
  end

  def unavailable?
    @unavailable == true
  end

  private

  def cache_unavailable(error = nil)
    @unavailable = true
    Rails.logger.warn("[ConfirmationEmailRateLimiter] Cache unavailable: #{error ? error.class : 'no counter returned'}")
    false
  end
end
