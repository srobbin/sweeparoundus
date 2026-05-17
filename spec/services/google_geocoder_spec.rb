require "rails_helper"

RSpec.describe GoogleGeocoder, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  # Test env defaults to :null_store; use a real in-memory store so
  # cache round-trip assertions actually exercise the cache.
  let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

  # Thin subclass for testing the base class. Real subclass behavior is
  # covered in the GeocodeAddress and ReverseGeocodeAddress specs.
  let(:subclass) do
    Class.new(GoogleGeocoder) do
      def initialize(query:)
        @query = query
      end

      private

      def query_params
        { address: @query }
      end

      def cache_key
        "test_geocoder:#{@query}"
      end

      def log_identifier
        @query
      end

      def parse_success(json)
        json.dig("results", 0, "formatted_address")
      end
    end
  end

  subject { subclass.new(query: "Anywhere") }

  before do
    allow(Rails).to receive(:cache).and_return(memory_cache)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("GOOGLE_MAPS_BACKEND_API_KEY").and_return("test-key")
    # Make retry math instant so "exhaust the retries" tests don't actually sleep.
    stub_const("GoogleGeocoder::RETRY_BASE_DELAY", 0)
  end

  describe "successful response" do
    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: { status: "OK", results: [ { formatted_address: "1 Main St" } ] }.to_json)
    end

    it "returns the parsed value" do
      expect(subject.call).to eq("1 Main St")
    end

    it "leaves error_reason nil after success" do
      subject.call
      expect(subject.error_reason).to be_nil
    end

    it "caches the value with the long CACHE_TTL" do
      freeze_time do
        subject.call
        travel described_class::CACHE_TTL - 1.second
        expect(subclass.new(query: "Anywhere").call).to eq("1 Main St")
        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
      end
    end

    it "expires the cached value after CACHE_TTL" do
      freeze_time do
        subject.call
        travel described_class::CACHE_TTL + 1.second
        subclass.new(query: "Anywhere").call
        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).twice
      end
    end
  end

  describe "ZERO_RESULTS" do
    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: { status: "ZERO_RESULTS", results: [] }.to_json)
    end

    it "returns nil and surfaces a granular error_reason" do
      expect(subject.call).to be_nil
      expect(subject.error_reason).to eq("geocode_status: ZERO_RESULTS")
    end

    it "caches the nil with NIL_CACHE_TTL (longer than ERROR_CACHE_TTL)" do
      freeze_time do
        subject.call
        travel described_class::NIL_CACHE_TTL - 1.second
        subclass.new(query: "Anywhere").call
        expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
      end
    end

    it "preserves the error_reason across cache hits" do
      subject.call
      next_call = subclass.new(query: "Anywhere")
      next_call.call
      expect(next_call.error_reason).to eq("geocode_status: ZERO_RESULTS")
    end
  end

  describe "OK with unparseable result" do
    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: { status: "OK", results: [ { formatted_address: nil } ] }.to_json)
    end

    it "returns nil with a distinct error_reason" do
      expect(subject.call).to be_nil
      expect(subject.error_reason).to eq("geocode_status: OK_NO_USABLE_RESULT")
    end
  end

  describe "transient API statuses" do
    before { allow(Rails.logger).to receive(:warn) }

    %w[OVER_QUERY_LIMIT UNKNOWN_ERROR].each do |status|
      context status do
        it "retries up to MAX_RETRIES, then returns nil with a status-flavored error_reason" do
          stub_request(:get, /maps.googleapis.com/)
            .to_return(body: { status: status, results: [] }.to_json)

          expect(subject.call).to be_nil
          expect(subject.error_reason).to eq("geocode_status: #{status}")
          expect(WebMock).to have_requested(:get, /maps.googleapis.com/)
            .times(described_class::MAX_RETRIES + 1)
        end

        it "returns the parsed result if a retry succeeds" do
          stub_request(:get, /maps.googleapis.com/)
            .to_return(body: { status: status, results: [] }.to_json).then
            .to_return(body: { status: "OK", results: [ { formatted_address: "Recovered" } ] }.to_json)

          expect(subject.call).to eq("Recovered")
          expect(subject.error_reason).to be_nil
        end
      end
    end
  end

  describe "non-retryable API statuses" do
    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: { status: "REQUEST_DENIED", results: [] }.to_json)
      allow(Rails.logger).to receive(:warn)
    end

    it "does not retry and returns nil with the status as error_reason" do
      expect(subject.call).to be_nil
      expect(subject.error_reason).to eq("geocode_status: REQUEST_DENIED")
      expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
    end

    it "logs a warning" do
      subject.call
      expect(Rails.logger).to have_received(:warn).with(/REQUEST_DENIED/)
    end

    it "caches with the short ERROR_CACHE_TTL, not the longer NIL_CACHE_TTL" do
      freeze_time do
        subject.call
        travel described_class::ERROR_CACHE_TTL + 1.second
        expect(memory_cache.read("test_geocoder:Anywhere")).to be_nil
      end
    end
  end

  describe "HTTP errors" do
    before { allow(Rails.logger).to receive(:warn) }

    [ 500, 502, 503, 504, 429 ].each do |code|
      context "HTTP #{code}" do
        it "retries and eventually surfaces an http_status error_reason" do
          stub_request(:get, /maps.googleapis.com/).to_return(status: code, body: "boom")

          expect(subject.call).to be_nil
          expect(subject.error_reason).to eq("http_status: #{code}")
          expect(WebMock).to have_requested(:get, /maps.googleapis.com/)
            .times(described_class::MAX_RETRIES + 1)
        end
      end
    end

    it "recovers when an early 5xx is followed by a 200" do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(status: 503, body: "Unavailable").then
        .to_return(body: { status: "OK", results: [ { formatted_address: "Recovered" } ] }.to_json)

      expect(subject.call).to eq("Recovered")
    end

    [ 400, 401, 403, 404 ].each do |code|
      context "HTTP #{code}" do
        it "does not retry and surfaces an http_status error_reason" do
          stub_request(:get, /maps.googleapis.com/).to_return(status: code, body: "no")

          expect(subject.call).to be_nil
          expect(subject.error_reason).to eq("http_status: #{code}")
          expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
        end
      end
    end
  end

  describe "network exceptions" do
    before { allow(Rails.logger).to receive(:warn) }

    [ Net::OpenTimeout, Net::ReadTimeout, Errno::ECONNRESET ].each do |error_class|
      context error_class.name do
        it "retries and eventually surfaces an http_error reason" do
          stub_request(:get, /maps.googleapis.com/).to_raise(error_class.new("boom"))

          expect(subject.call).to be_nil
          expect(subject.error_reason).to start_with("http_error:")
          expect(WebMock).to have_requested(:get, /maps.googleapis.com/)
            .times(described_class::MAX_RETRIES + 1)
        end
      end
    end

    it "does not retry on generic StandardError and reports it" do
      stub_request(:get, /maps.googleapis.com/).to_raise(StandardError.new("Network error"))

      expect(subject.call).to be_nil
      expect(subject.error_reason).to eq("http_error: Network error")
      expect(WebMock).to have_requested(:get, /maps.googleapis.com/).once
    end
  end

  describe "API key" do
    it "returns nil without making a request when the key is missing" do
      allow(ENV).to receive(:[]).with("GOOGLE_MAPS_BACKEND_API_KEY").and_return(nil)

      expect(subject.call).to be_nil
      expect(WebMock).not_to have_requested(:get, /maps.googleapis.com/)
    end

    it "appends the key as a query param" do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: { status: "OK", results: [ { formatted_address: "X" } ] }.to_json)

      subject.call

      expect(WebMock).to have_requested(:get, /maps.googleapis.com/)
        .with(query: hash_including("key" => "test-key"))
    end
  end

  describe "caching shape backwards compatibility" do
    it "treats legacy hash entries (no :value key) as a cache miss and re-fetches" do
      memory_cache.write("test_geocoder:Anywhere", { address: "stale-format" })

      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: { status: "OK", results: [ { formatted_address: "Fresh" } ] }.to_json)

      expect(subject.call).to eq("Fresh")
    end
  end

  describe "blank query short-circuit" do
    let(:blank_subclass) do
      Class.new(GoogleGeocoder) do
        def initialize; end
        private
        def blank_query?; true; end
        def cache_key; "noop"; end
      end
    end

    it "returns nil without a cache hit, HTTP request, or error_reason" do
      service = blank_subclass.new
      expect(service.call).to be_nil
      expect(service.error_reason).to be_nil
      expect(WebMock).not_to have_requested(:get, /maps.googleapis.com/)
    end
  end

  describe "abstract method enforcement" do
    let(:incomplete_subclass) do
      Class.new(GoogleGeocoder) do
        def initialize; end
        private
        def cache_key; "noop"; end
      end
    end

    it "raises NotImplementedError if subclass does not define query_params" do
      service = incomplete_subclass.new
      expect { service.call }.to raise_error(NotImplementedError, /query_params/)
    end
  end
end
