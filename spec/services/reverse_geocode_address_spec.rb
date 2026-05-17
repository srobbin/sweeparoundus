require "rails_helper"

RSpec.describe ReverseGeocodeAddress, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:lat) { 41.88500 }
  let(:lng) { -87.70600 }
  # Test env defaults to :null_store; use a real in-memory store so
  # cache round-trip assertions actually exercise the cache.
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  subject { described_class.new(lat: lat, lng: lng) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_MAPS_BACKEND_API_KEY").and_return("test-key")
    stub_const("GoogleGeocoder::RETRY_BASE_DELAY", 0)
  end

  describe "#call" do
    context "when the API returns a valid result" do
      before do
        stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/)
          .to_return(body: {
            status: "OK",
            results: [ { formatted_address: "3300 N California Ave, Chicago, IL 60618, USA" } ]
          }.to_json)
      end

      it "returns the formatted address with trailing USA stripped" do
        expect(subject.call).to eq("3300 N California Ave, Chicago, IL 60618")
      end

      it "passes the lat,lng as the `latlng` query param" do
        subject.call
        expect(WebMock).to have_requested(:get, /maps.googleapis.com/)
          .with(query: hash_including("latlng" => "#{lat},#{lng}", "key" => "test-key"))
      end

      it "caches the address for CACHE_TTL and reuses it on subsequent calls" do
        subject.call
        described_class.new(lat: lat, lng: lng).call

        expect(WebMock).to have_requested(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/).once
      end
    end

    context "when the API returns ZERO_RESULTS" do
      before do
        stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/)
          .to_return(body: { status: "ZERO_RESULTS", results: [] }.to_json)
      end

      it "returns nil" do
        expect(subject.call).to be_nil
      end

      it "exposes a granular error_reason" do
        subject.call
        expect(subject.error_reason).to eq("geocode_status: ZERO_RESULTS")
      end

      it "caches the nil result to prevent repeated API calls" do
        subject.call
        described_class.new(lat: lat, lng: lng).call

        expect(WebMock).to have_requested(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/).once
      end

      it "caches a hash wrapper with nil value to distinguish from a cache miss" do
        subject.call
        cached = memory_cache.read("reverse_geocode:#{lat.round(5)},#{lng.round(5)}")

        expect(cached).to be_a(Hash)
        expect(cached).to have_key(:value)
        expect(cached[:value]).to be_nil
      end
    end

    context "when the API returns a non-retryable error status" do
      before do
        stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/)
          .to_return(body: { status: "REQUEST_DENIED", results: [] }.to_json)
        allow(Rails.logger).to receive(:warn)
      end

      it "returns nil and logs a warning" do
        expect(subject.call).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/REQUEST_DENIED/)
      end

      it "does not retry within the request" do
        subject.call
        expect(WebMock).to have_requested(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/).once
      end

      it "caches with ERROR_CACHE_TTL, not the longer NIL_CACHE_TTL" do
        freeze_time do
          subject.call
          travel GoogleGeocoder::ERROR_CACHE_TTL + 1.second
          expect(memory_cache.read("reverse_geocode:#{lat.round(5)},#{lng.round(5)}")).to be_nil
        end
      end
    end

    context "when the API returns OVER_QUERY_LIMIT (retryable)" do
      before { allow(Rails.logger).to receive(:warn) }

      it "retries and recovers if a later attempt succeeds" do
        stub_request(:get, /maps.googleapis.com/)
          .to_return(body: { status: "OVER_QUERY_LIMIT", results: [] }.to_json).then
          .to_return(body: { status: "OK", results: [ { formatted_address: "Recovered" } ] }.to_json)

        expect(subject.call).to eq("Recovered")
      end
    end

    context "when the HTTP response is non-200" do
      before do
        stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/)
          .to_return(status: 500, body: "Internal Server Error")
        allow(Rails.logger).to receive(:warn)
      end

      it "returns nil and logs the HTTP status" do
        expect(subject.call).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/HTTP 500/)
      end

      it "caches the nil result with ERROR_CACHE_TTL" do
        freeze_time do
          subject.call
          travel GoogleGeocoder::ERROR_CACHE_TTL + 1.second
          expect(memory_cache.read("reverse_geocode:#{lat.round(5)},#{lng.round(5)}")).to be_nil
        end
      end
    end

    context "when the network call raises" do
      before do
        stub_request(:get, /maps.googleapis.com\/maps\/api\/geocode\/json/)
          .to_raise(Net::OpenTimeout.new("timed out"))
        allow(Rails.logger).to receive(:warn)
      end

      it "returns nil and logs a warning" do
        expect(subject.call).to be_nil
        expect(Rails.logger).to have_received(:warn).with(/Net::OpenTimeout/)
      end

      it "caches the nil result with ERROR_CACHE_TTL" do
        freeze_time do
          subject.call
          travel GoogleGeocoder::ERROR_CACHE_TTL + 1.second
          expect(memory_cache.read("reverse_geocode:#{lat.round(5)},#{lng.round(5)}")).to be_nil
        end
      end
    end

    context "when the API key is not configured" do
      before do
        allow(ENV).to receive(:[]).with("GOOGLE_MAPS_BACKEND_API_KEY").and_return(nil)
      end

      it "returns nil without making an HTTP request" do
        expect(subject.call).to be_nil
        expect(WebMock).not_to have_requested(:get, /maps.googleapis.com/)
      end
    end
  end
end
