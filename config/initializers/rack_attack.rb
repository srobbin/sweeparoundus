class Rack::Attack
  API_RATE_LIMIT = 60
  API_RATE_PERIOD = 1.hour

  if Rails.env.test?
    cache.store = ActiveSupport::Cache::MemoryStore.new
  else
    cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  end

  throttle("api/ip", limit: API_RATE_LIMIT, period: API_RATE_PERIOD) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [{ error: "Rate limit exceeded. Try again later." }.to_json]
    ]
  end
end
