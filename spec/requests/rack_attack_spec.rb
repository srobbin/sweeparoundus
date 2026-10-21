require "rails_helper"

RSpec.describe "Rack::Attack", type: :request do
  include ActiveSupport::Testing::TimeHelpers

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
      4.times do
        post "/subscriptions/send_link", params: { email: "test@example.com" },
          headers: { "Accept" => "application/json" }
      end

      expect(response).to have_http_status(429)
      expect(response.media_type).to eq("application/json")
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Rate limit exceeded. Try again later.")
      expect(response.headers["Cache-Control"]).to eq("no-store")
    end

    it "serves an uncached error page when a browser exceeds the limit" do
      4.times do
        post "/subscriptions/send_link", params: { email: "test@example.com" },
          headers: { "Accept" => "text/html" }
      end

      expect(response).to have_http_status(429)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Too many requests")
      expect(response.headers["Cache-Control"]).to eq("no-store")
      expect(response.headers["Retry-After"]).to be_present
    end

    it "does not throttle GET requests to subscriptions" do
      4.times { get "/subscriptions" }

      expect(response).not_to have_http_status(429)
    end
  end

  describe "public signup rate limiting" do
    let!(:area) { create(:area) }

    it "blocks excess signups even when the email changes" do
      Rack::Attack::SIGNUP_RATE_LIMIT.times do |i|
        post area_alerts_path(area), params: { email: "invalid-#{i}" }
        expect(response).not_to have_http_status(429)
      end

      expect(Subscriber).not_to receive(:find_or_create_by!)
      post area_alerts_path(area), params: { email: "another-invalid-email" }
      expect(response).to have_http_status(429)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "shares the signup budget with formatted and normalized URLs" do
      Rack::Attack::SIGNUP_RATE_LIMIT.times do
        post area_alerts_path(area), params: { email: "invalid" }
      end
      path = area_alerts_path(area)
      [ "#{path}.json", "#{path}/", "#{path}//", "/#{path}", path.sub("/alerts", "//alerts") ].each do |variant|
        post path, params: { email: "invalid" }, env: { "PATH_INFO" => variant }
        expect(response).to have_http_status(429)
      end
    end

    it "counts repeated-slash signup requests before a canonical request" do
      path = area_alerts_path(area)
      Rack::Attack::SIGNUP_RATE_LIMIT.times do
        post path, params: { email: "invalid" }, env: { "PATH_INFO" => "#{path}//" }
        expect(response).to have_http_status(:found)
      end
      expect(Subscriber).not_to receive(:find_or_create_by!)
      post path, params: { email: "invalid" }
      expect(response).to have_http_status(429)
    end
  end

  describe "search rate limiting" do
    it "counts HEAD and GET requests toward the same budget before geocoding" do
      geocoder = instance_double(GeocodeAddress, call: nil)
      allow(GeocodeAddress).to receive(:new).and_return(geocoder)
      params = { lat: "1", lng: "1", address: "123 Main St" }

      head "/search", params: params
      expect(GeocodeAddress).to have_received(:new).once
      (Rack::Attack::SEARCH_RATE_LIMIT - 1).times { get "/search", params: params }
      expect(GeocodeAddress).to have_received(:new).exactly(Rack::Attack::SEARCH_RATE_LIMIT).times
      expect(GeocodeAddress).not_to receive(:new)

      head "/search", params: params
      expect(response).to have_http_status(429)
      expect(response.body).to be_empty
      expect(response.headers["Retry-After"]).to be_present
      get "/search", params: params
      expect(response).to have_http_status(429)
    end

    it "blocks excess requests before invoking the geocoder" do
      geocoder = instance_double(GeocodeAddress, call: nil)
      allow(GeocodeAddress).to receive(:new).and_return(geocoder)

      Rack::Attack::SEARCH_RATE_LIMIT.times do |i|
        get "/search", params: { lat: "1", lng: "1", address: "#{i} Main St" }
        expect(response).not_to have_http_status(429)
      end
      expect(GeocodeAddress).to have_received(:new).exactly(Rack::Attack::SEARCH_RATE_LIMIT).times
      expect(GeocodeAddress).not_to receive(:new)

      get "/search", params: { lat: "1", lng: "1", address: "another address" }
      expect(response).to have_http_status(429)
      expect(response.headers["Retry-After"]).to be_present
    end

    it "serves accessible HTML to browsers, while keeping API errors JSON" do
      Rack::Attack::SEARCH_RATE_LIMIT.times { get "/search" }
      get "/search", headers: { "Accept" => "text/html" }

      expect(response).to have_http_status(429)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include("Too many requests", '<html lang="en">', '<meta name="viewport"')
      expect(response.headers["Cache-Control"]).to eq("no-store")

      (Rack::Attack::API_RATE_LIMIT + 1).times do
        get "/api/v1/sweeps", headers: { "Accept" => "text/html" }
      end
      expect(response).to have_http_status(429)
      expect(response.media_type).to eq("application/json")
    end

    it "shares the search budget across URL formats but not different IPs" do
      Rack::Attack::SEARCH_RATE_LIMIT.times { get "/search" }
      [ "/search.json", "/search/", "/search//", "///search" ].each do |path|
        get "/search", env: { "PATH_INFO" => path }
        expect(response).to have_http_status(429)
      end

      get "/search", env: { "REMOTE_ADDR" => "203.0.113.20" }
      expect(response).not_to have_http_status(429)
    end

    it "counts repeated-slash HEAD searches toward the canonical GET budget" do
      geocoder = instance_double(GeocodeAddress, call: nil)
      allow(GeocodeAddress).to receive(:new).and_return(geocoder)
      Rack::Attack::SEARCH_RATE_LIMIT.times do
        head "/search", params: { lat: "1", lng: "1", address: "123 Main St" },
          env: { "PATH_INFO" => "///search//" }
        expect(response).to have_http_status(:found)
      end
      expect(GeocodeAddress).to have_received(:new).exactly(Rack::Attack::SEARCH_RATE_LIMIT).times
      expect(GeocodeAddress).not_to receive(:new)
      get "/search", params: { lat: "1", lng: "1", address: "123 Main St" }
      expect(response).to have_http_status(429)
    end

    it "allows requests again when the rate-limit window expires" do
      travel_to(Time.utc(2026, 6, 1, 12, 0, 10)) do
        Rack::Attack::SEARCH_RATE_LIMIT.times { get "/search" }
        get "/search"
        expect(response).to have_http_status(429)
        expect(response.headers["Retry-After"].to_i).to eq(290)

        travel 291.seconds
        get "/search"
        expect(response).not_to have_http_status(429)
      end
    end
  end
end
