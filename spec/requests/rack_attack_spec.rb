require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  before do
    Rack::Attack.cache.store.clear
  end

  after do
    Rack::Attack.cache.store.clear
  end

  describe "API rate limiting" do
    around do |example|
      Rack::Attack.throttle("api/ip", limit: 3, period: 300) do |req|
        req.ip if req.path.start_with?("/api/")
      end
      example.run
      Rack::Attack.throttle("api/ip", limit: Rack::Attack::API_RATE_LIMIT, period: Rack::Attack::API_RATE_PERIOD) do |req|
        req.ip if req.path.start_with?("/api/")
      end
    end

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

  describe "send_link rate limiting" do
    around do |example|
      Rack::Attack.throttle("subscriptions/send_link/ip", limit: 3, period: 300) do |req|
        req.ip if req.path == "/subscriptions/send_link" && req.post?
      end
      example.run
      Rack::Attack.throttle("subscriptions/send_link/ip", limit: Rack::Attack::SEND_LINK_RATE_LIMIT, period: Rack::Attack::SEND_LINK_RATE_PERIOD) do |req|
        req.ip if req.path == "/subscriptions/send_link" && req.post?
      end
    end

    it "allows requests within the limit" do
      3.times { post "/subscriptions/send_link", params: { email: "test@example.com" } }

      expect(response).not_to have_http_status(429)
    end

    it "throttles requests exceeding the limit" do
      4.times { post "/subscriptions/send_link", params: { email: "test@example.com" } }

      expect(response).to have_http_status(429)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Rate limit exceeded. Try again later.")
    end

    it "does not throttle GET requests to subscriptions" do
      4.times { get "/subscriptions" }

      expect(response).not_to have_http_status(429)
    end
  end

  describe "send_link per-email rate limiting" do
    around do |example|
      Rack::Attack.throttle("subscriptions/send_link/email", limit: 3, period: 300) do |req|
        req.params["email"].to_s.strip.downcase.presence if req.path == "/subscriptions/send_link" && req.post?
      end
      example.run
      Rack::Attack.throttle("subscriptions/send_link/email", limit: Rack::Attack::SEND_LINK_EMAIL_RATE_LIMIT, period: Rack::Attack::SEND_LINK_EMAIL_RATE_PERIOD) do |req|
        req.params["email"].to_s.strip.downcase.presence if req.path == "/subscriptions/send_link" && req.post?
      end
    end

    it "allows requests within the limit for the same email" do
      3.times { post "/subscriptions/send_link", params: { email: "test@example.com" } }

      expect(response).not_to have_http_status(429)
    end

    it "throttles requests exceeding the limit for the same email" do
      4.times { post "/subscriptions/send_link", params: { email: "test@example.com" } }

      expect(response).to have_http_status(429)
    end

    it "tracks different emails separately" do
      3.times { post "/subscriptions/send_link", params: { email: "test@example.com" } }
      post "/subscriptions/send_link", params: { email: "other@example.com" }

      expect(response).not_to have_http_status(429)
    end
  end
end
