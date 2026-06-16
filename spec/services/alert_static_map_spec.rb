# frozen_string_literal: true

require "rails_helper"

RSpec.describe AlertStaticMap, type: :service do
  AlertCoords = Struct.new(:lat, :lng) unless defined?(AlertCoords)

  let(:alert) { AlertCoords.new(41.881, -87.706) }

  let(:factory) { RGeo::Geos.factory(srid: 0) }
  let(:polygon) do
    factory.parse_wkt(
      "MULTIPOLYGON (((-87.710 41.878, -87.700 41.878, -87.700 41.884, -87.710 41.884, -87.710 41.878)))"
    )
  end
  let(:area) { double("Area", shape: polygon) }

  subject { described_class.new(alert: alert, area: area) }

  around do |example|
    original = ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = "test-key"
    example.run
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = original
  end

  describe "#url" do
    it "starts with the Static Maps API base URL" do
      expect(subject.url).to start_with("https://maps\.googleapis\.com/maps/api/staticmap?")
    end

    it "includes the configured API key" do
      expect(subject.url).to include("key=test-key")
    end

    it "includes a blue 'H' marker at the alert's coords" do
      expect(subject.url).to include(
        "markers=" + URI.encode_www_form_component("color:blue|label:H|41.881,-87.706")
      )
    end

    it "includes a path param with fill and border styling" do
      url = subject.url
      expect(url).to include("path=")
      encoded = URI.decode_www_form_component(url)
      first_colors = AlertStaticMap::PALETTE[0]
      expect(encoded).to include("fillcolor:#{first_colors[:fill]}")
      expect(encoded).to include("color:#{first_colors[:border]}")
      expect(encoded).to include("enc:")
    end

    it "uses size, scale, and roadmap parameters" do
      url = subject.url
      expect(url).to include("size=480x320")
      expect(url).to include("scale=2")
      expect(url).to include("maptype=roadmap")
    end

    context "when alert has no coordinates" do
      let(:alert) { AlertCoords.new(nil, nil) }

      it "returns a valid URL without a marker" do
        url = subject.url
        expect(url).to start_with("https://maps\.googleapis\.com/maps/api/staticmap?")
        expect(url).not_to include("markers=")
      end
    end

    context "when area has no shape" do
      let(:area) { double("Area", shape: nil) }

      it "returns nil" do
        expect(subject.url).to be_nil
      end
    end

    context "when area is nil" do
      let(:area) { nil }

      it "returns nil" do
        expect(subject.url).to be_nil
      end
    end

    context "when alert coords are BigDecimals" do
      let(:alert) { AlertCoords.new(BigDecimal("41.881000"), BigDecimal("-87.706000")) }

      it "formats them in plain decimal, not scientific notation" do
        url = subject.url
        expect(url).to include(
          "markers=" + URI.encode_www_form_component("color:blue|label:H|41.881,-87.706")
        )
        expect(url).not_to match(/0\.\d+e\d/i)
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

    context "with a simple Polygon shape (not Multi)" do
      let(:polygon) do
        factory.parse_wkt(
          "POLYGON ((-87.710 41.878, -87.700 41.878, -87.700 41.884, -87.710 41.884, -87.710 41.878))"
        )
      end

      it "still produces a valid URL" do
        expect(subject.url).to start_with("https://maps\.googleapis\.com/maps/api/staticmap?")
      end
    end

    context "with a MultiPolygon containing tiny artifacts" do
      let(:polygon) do
        wkt = <<~WKT.squish
          MULTIPOLYGON (
            ((-87.6857654 41.8572053, -87.6857656 41.8572053, -87.6857656 41.8572055, -87.6857654 41.8572053)),
            ((-87.686 41.857, -87.666 41.857, -87.666 41.876, -87.686 41.876, -87.686 41.857)),
            ((-87.700 41.860, -87.695 41.860, -87.695 41.865, -87.700 41.865, -87.700 41.860))
          )
        WKT

        factory.parse_wkt(wkt)
      end

      it "emits a path for each significant component and skips tiny slivers" do
        url = subject.url
        decoded = URI.decode_www_form_component(url)
        first_colors = AlertStaticMap::PALETTE[0]

        expect(url.scan("path=").size).to eq(2)
        expect(decoded.scan("fillcolor:#{first_colors[:fill]}").size).to eq(2)
      end
    end
  end

  describe "with multiple areas" do
    let(:polygon2) do
      factory.parse_wkt(
        "MULTIPOLYGON (((-87.690 41.860, -87.680 41.860, -87.680 41.870, -87.690 41.870, -87.690 41.860)))"
      )
    end
    let(:area2) { double("Area", shape: polygon2) }

    subject { described_class.new(alert: alert, areas: [ area, area2 ]) }

    it "includes a path param for each area" do
      url = subject.url
      path_count = url.scan("path=").size
      expect(path_count).to eq(2)
    end

    it "uses distinct colors for each area" do
      decoded = URI.decode_www_form_component(subject.url)
      colors = AlertStaticMap::PALETTE
      expect(decoded).to include("fillcolor:#{colors[0][:fill]}")
      expect(decoded).to include("fillcolor:#{colors[1][:fill]}")
    end

    it "still produces a valid URL" do
      expect(subject.url).to start_with("https://maps\.googleapis\.com/maps/api/staticmap?")
    end

    context "when one area has no shape" do
      let(:area2) { double("Area", shape: nil) }

      it "renders the valid area and skips the nil one" do
        url = subject.url
        expect(url).to start_with("https://maps\.googleapis\.com/maps/api/staticmap?")
        expect(url.scan("path=").size).to eq(1)
      end
    end

    context "when all areas have no shape" do
      let(:area) { double("Area", shape: nil) }
      let(:area2) { double("Area", shape: nil) }

      it "returns nil" do
        expect(subject.url).to be_nil
      end
    end
  end

  describe "#encode_polyline (via URL)" do
    it "produces a decodable encoded polyline in the path" do
      url = subject.url
      path_segment = URI.decode_www_form_component(url)[/enc:([^\s&]+)/, 1]
      expect(path_segment).to be_present
    end
  end
end
