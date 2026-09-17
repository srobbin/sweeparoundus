require "digest"

class ManageLinkRateLimiter
  LIMIT = 4
  PERIOD = 1.hour

  def initialize(email)
    @email = email
  end

  def allowed?
    count = Rack::Attack.cache.store.increment(
      cache_key,
      1,
      expires_in: PERIOD
    )

    count.present? && count <= LIMIT
  end

  private

  attr_reader :email

  def cache_key
    "manage-link/email/#{Digest::SHA256.hexdigest(email)}"
  end
end
