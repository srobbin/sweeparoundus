require "rails_helper"

RSpec.describe GeocodeAddress, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  let(:address) { "3300 N California Ave, Chicago, IL" }
  # Test env defaults to :null_store; use a real in-memory store so
  # cache round-trip assertions actually exercise the cache.
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  subject { described_class.new(address: address) }

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_MAPS_BACKEND_API_KEY").and_return("test-key")
    stub_const("GoogleGeocoder::RETRY_BASE_DELAY", 0)
  end

  describe "#call" do
    context "when the API returns a valid result" do
      before do
        stub_request(:get, /maps.googleapis.com/)
          .to_return(body: {
            status: "OK",
            results: [ { geometry: { location: { lat: 41.94142, lng: -87.69870 } } } ]
          }.to_json)
      end

      it "returns a Result struct with lat and lng coerced to Float" do
        result = subject.call
        expect(result).to be_a(GeocodeAddress::Result)
        expect(result.lat).to eq(41.94142)
        expect(result.lng).to eq(-87.69870)
        expect(result.lat).to be_a(Float)
      end

      it "leaves error_reason nil after success" do
        subject.call
        expect(subject.error_reason).to be_nil
      end

      it "passes the address as the `address` query param" do
        subject.call
        expect(WebMock).to have_requested(:get, /maps.googleapis.com/)
          .with(query: hash_including("address" => address, "key" => "test-key"))
      end

      it "caches the result and reuses it on subsequent calls" do
        subject.call
        described_class.new(address: address).call

        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
      end

      it "is case-insensitive in the cache key" do
        subject.call
        described_class.new(address: address.upcase).call

        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
      end

      it "trims whitespace before caching" do
        subject.call
        described_class.new(address: "   #{address}   ").call

        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
      end
    end

    context "when the API returns OK but with no usable geometry" do
      before do
        stub_request(:get, /maps.googleapis.com/)
          .to_return(body: { status: "OK", results: [ { geometry: { location: {} } } ] }.to_json)
      end

      it "returns nil with the OK_NO_USABLE_RESULT error_reason" do
        expect(subject.call).to be_nil
        expect(subject.error_reason).to eq("geocode_status: OK_NO_USABLE_RESULT")
      end
    end

    context "when the API returns ZERO_RESULTS" do
      before do
        stub_request(:get, /maps.googleapis.com/)
          .to_return(body: { status: "ZERO_RESULTS", results: [] }.to_json)
      end

      it "returns nil with the ZERO_RESULTS error_reason" do
        expect(subject.call).to be_nil
        expect(subject.error_reason).to eq("geocode_status: ZERO_RESULTS")
      end

      it "caches the nil to prevent repeated API calls" do
        subject.call
        described_class.new(address: address).call

        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
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

    context "when the address is blank" do
      it "returns nil without hitting the API or cache" do
        expect(described_class.new(address: "  ").call).to be_nil
        expect(WebMock).not_to have_requested(:get, /maps.googleapis.com/)
      end
    end

    context "when transient errors require retries" do
      it "retries on OVER_QUERY_LIMIT and recovers" do
        stub_request(:get, /maps.googleapis.com/)
          .to_return(body: { status: "OVER_QUERY_LIMIT", results: [] }.to_json).then
          .to_return(body: {
            status: "OK",
            results: [ { geometry: { location: { lat: 41.94142, lng: -87.69870 } } } ]
          }.to_json)

        result = subject.call
        expect(result.lat).to eq(41.94142)
      end

      it "retries on HTTP 5xx and recovers" do
        stub_request(:get, /maps.googleapis.com/)
          .to_return(status: 503, body: "Unavailable").then
          .to_return(body: {
            status: "OK",
            results: [ { geometry: { location: { lat: 41.94142, lng: -87.69870 } } } ]
          }.to_json)

        expect(subject.call.lat).to eq(41.94142)
      end
    end
  end
end
