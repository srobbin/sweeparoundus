require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  before do
    Rack::Attack.cache.store.clear
    Rack::Attack.throttle("api/ip", limit: 3, period: 300) do |req|
      req.ip if req.path.start_with?("/api/")
    end
  end

  after do
    Rack::Attack.cache.store.clear
    Rack::Attack.throttle("api/ip", limit: Rack::Attack::API_RATE_LIMIT, period: Rack::Attack::API_RATE_PERIOD) do |req|
      req.ip if req.path.start_with?("/api/")
    end
  end

  describe "API rate limiting" do
    it "allows requests within the limit" do
      3.times { get "/api/v1/sweeps" }

      expect(response).not_to have_http_status(429)
    end

    it "throttles requests exceeding the limit" do
      4.times { get "/api/v1/sweeps" }

      expect(response).to have_http_status(429)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Rate limit exceeded. Try again later.")
      expect(response.headers["Retry-After"]).to be_present
    end

    it "does not throttle non-API requests" do
      4.times { get "/" }

      expect(response).not_to have_http_status(429)
    end
  end
end
