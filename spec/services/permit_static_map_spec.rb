# frozen_string_literal: true

require "rails_helper"

RSpec.describe PermitStaticMap, type: :service do
  AlertCoords = Struct.new(:lat, :lng)

  let(:alert) { AlertCoords.new(41.94200, -87.69870) }
  let(:line_from) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }
  let(:line_to)   { GeocodeAddress::Result.new(lat: 41.94284, lng: -87.69870) }

  subject { described_class.new(alert: alert, line_from: line_from, line_to: line_to) }

  around do |example|
    original = ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = "test-key"
    example.run
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = original
  end

  describe "#url" do
    it "starts with the Static Maps API base URL" do
      expect(subject.url).to start_with("https://maps.googleapis.com/maps/api/staticmap?")
    end

    it "includes the configured API key" do
      expect(subject.url).to include("key=test-key")
    end

    it "includes a blue 'H' marker at the alert's coords" do
      expect(subject.url).to include(
        "markers=" + URI.encode_www_form_component("color:blue|label:H|41.942,-87.6987")
      )
    end

    it "includes 'A' and 'B' markers at the permit endpoints when they differ" do
      url = subject.url
      expect(url).to include(
        "markers=" + URI.encode_www_form_component("color:red|label:A|41.94142,-87.6987")
      )
      expect(url).to include(
        "markers=" + URI.encode_www_form_component("color:red|label:B|41.94284,-87.6987")
      )
    end

    it "includes a styled path connecting the two permit endpoints" do
      expect(subject.url).to include(
        "path=" + URI.encode_www_form_component(
          "color:0xff0000cc|weight:5|41.94142,-87.6987|41.94284,-87.6987"
        )
      )
    end

    it "uses size, scale, and roadmap parameters" do
      url = subject.url
      expect(url).to include("size=480x320")
      expect(url).to include("scale=2")
      expect(url).to include("maptype=roadmap")
    end

    context "when both endpoints are at the same point (degenerate line)" do
      let(:line_to) { GeocodeAddress::Result.new(lat: line_from.lat, lng: line_from.lng) }

      it "drops a single 'P' pin instead of drawing a path" do
        url = subject.url
        expect(url).to include(
          "markers=" + URI.encode_www_form_component("color:red|label:P|41.94142,-87.6987")
        )
        expect(url).not_to include("path=")
        expect(url).not_to include("label%3AA")
        expect(url).not_to include("label%3AB")
      end
    end

    context "when the alert has no coordinates" do
      let(:alert) { AlertCoords.new(nil, nil) }

      it "returns nil" do
        expect(subject.url).to be_nil
      end
    end

    context "when alert coords are BigDecimals (the AR-cast shape)" do
      let(:alert) { AlertCoords.new(BigDecimal("41.942000"), BigDecimal("-87.698700")) }

      it "formats them in plain decimal, not scientific notation" do
        url = subject.url
        expect(url).to include(
          "markers=" + URI.encode_www_form_component("color:blue|label:H|41.942,-87.6987")
        )
        expect(url).not_to match(/0\.41942e2/i)
      end
    end

    context "when an endpoint is missing" do
      let(:line_from) { nil }

      it "returns nil" do
        expect(subject.url).to be_nil
      end
    end

    context "when the API key is not configured" do
      around do |example|
        original = ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]
        ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = ""
        example.run
        ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = original
      end

      it "returns nil" do
        expect(subject.url).to be_nil
      end
    end
  end
end
