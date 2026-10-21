class Rack::Attack
  API_RATE_LIMIT = 60
  API_RATE_PERIOD = 1.hour

  SEND_LINK_RATE_LIMIT = 5
  SEND_LINK_RATE_PERIOD = 15.minutes

  SIGNUP_RATE_LIMIT = 5
  SIGNUP_RATE_PERIOD = 15.minutes
  SEARCH_RATE_LIMIT = 30
  SEARCH_RATE_PERIOD = 5.minutes

  ICS_RATE_LIMIT = 10
  ICS_RATE_PERIOD = 1.hour

  CSP_REPORT_RATE_LIMIT = 30
  CSP_REPORT_RATE_PERIOD = 1.minute

  RATE_LIMIT_PAGE = Rails.root.join("public/429.html").read.freeze

  if Rails.env.test?
    cache.store = ActiveSupport::Cache::MemoryStore.new
  else
    cache.store = ActiveSupport::Cache::RedisCacheStore.new(url: ENV["REDIS_URL"], ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE })
  end

  throttle("api/ip", limit: API_RATE_LIMIT, period: API_RATE_PERIOD) do |req|
    req.ip if req.path.start_with?("/api/")
  end

  throttle("signup/ip", limit: SIGNUP_RATE_LIMIT, period: SIGNUP_RATE_PERIOD) do |req|
    path = ActionDispatch::Journey::Router::Utils.normalize_path(req.path)
    req.ip if req.post? && path.match?(%r{\A/areas/[^/]+/alerts(?:\.[^/]+)?\z})
  end

  throttle("search/ip", limit: SEARCH_RATE_LIMIT, period: SEARCH_RATE_PERIOD) do |req|
    path = ActionDispatch::Journey::Router::Utils.normalize_path(req.path)
    req.ip if (req.get? || req.head?) && path.match?(%r{\A/search(?:\.[^/]+)?\z})
  end

  throttle("subscriptions/send_link/ip", limit: SEND_LINK_RATE_LIMIT, period: SEND_LINK_RATE_PERIOD) do |req|
    req.ip if req.path == "/subscriptions/send_link" && req.post?
  end

  throttle("ics/ip", limit: ICS_RATE_LIMIT, period: ICS_RATE_PERIOD) do |req|
    req.ip if req.path.end_with?(".ics") && req.get?
  end

  throttle("csp_reports/ip", limit: CSP_REPORT_RATE_LIMIT, period: CSP_REPORT_RATE_PERIOD) do |req|
    req.ip if req.path == "/csp-violation-report" && req.post?
  end

  self.throttled_responder = lambda do |req|
    match_data = req.env["rack.attack.match_data"] || {}
    period = match_data.fetch(:period, 60).to_i
    retry_after = period - match_data.fetch(:epoch_time, Time.now.to_i).to_i % period
    html = !req.path.start_with?("/api/") && !req.path.end_with?(".json") &&
      req.get_header("HTTP_ACCEPT").to_s.include?("text/html")
    [
      429,
      {
        "content-type" => html ? "text/html; charset=utf-8" : "application/json",
        "retry-after" => retry_after.to_s,
        "cache-control" => "no-store",
        "vary" => "Accept"
      },
      [ html ? RATE_LIMIT_PAGE : { error: "Rate limit exceeded. Try again later." }.to_json ]
    ]
  end
end
