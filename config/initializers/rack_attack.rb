class Rack::Attack
  API_RATE_LIMIT = 60
  API_RATE_PERIOD = 1.hour

  SEND_LINK_RATE_LIMIT = 5
  SEND_LINK_RATE_PERIOD = 15.minutes

  SEND_LINK_EMAIL_RATE_LIMIT = 4
  SEND_LINK_EMAIL_RATE_PERIOD = 1.hour

  ICS_RATE_LIMIT = 10
  ICS_RATE_PERIOD = 1.hour

  CSP_REPORT_RATE_LIMIT = 30
  CSP_REPORT_RATE_PERIOD = 1.minute

  if Rails.env.test?
    cache.store = ActiveSupport::Cache::MemoryStore.new
  else
    cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  end

  throttle("api/ip", limit: API_RATE_LIMIT, period: API_RATE_PERIOD) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  throttle("subscriptions/send_link/ip", limit: SEND_LINK_RATE_LIMIT, period: SEND_LINK_RATE_PERIOD) do |req|
    req.ip if req.path == "/subscriptions/send_link" && req.post?
  end

  throttle("subscriptions/send_link/email", limit: SEND_LINK_EMAIL_RATE_LIMIT, period: SEND_LINK_EMAIL_RATE_PERIOD) do |req|
    req.params["email"].to_s.strip.downcase.presence if req.path == "/subscriptions/send_link" && req.post?
  end

  throttle("ics/ip", limit: ICS_RATE_LIMIT, period: ICS_RATE_PERIOD) do |req|
    req.ip if req.path.end_with?(".ics") && req.get?
  end

  throttle("csp_reports/ip", limit: CSP_REPORT_RATE_LIMIT, period: CSP_REPORT_RATE_PERIOD) do |req|
    req.ip if req.path == "/csp-violation-report" && req.post?
  end

  self.throttled_responder = lambda do |req|
    retry_after = (req.env["rack.attack.match_data"] || {})[:period]
    [
      429,
      { "Content-Type" => "application/json", "Retry-After" => retry_after.to_s },
      [ { error: "Rate limit exceeded. Try again later." }.to_json ]
    ]
  end
end
