require "rails_helper"

RSpec.describe FindAdjacentSweepAreas, type: :service do
  let(:factory) { RGeo::Geos.factory(srid: 0) }

  # Two abutting square polygons sharing an edge at lng = -87.706
  # Area A: western square  (-87.710 to -87.706, 41.884 to 41.888)
  # Area B: eastern square  (-87.706 to -87.702, 41.884 to 41.888)
  let(:shape_a) do
    factory.parse_wkt(
      "MULTIPOLYGON (((-87.710 41.884, -87.706 41.884, -87.706 41.888, -87.710 41.888, -87.710 41.884)))"
    )
  end

  let(:shape_b) do
    factory.parse_wkt(
      "MULTIPOLYGON (((-87.706 41.884, -87.702 41.884, -87.702 41.888, -87.706 41.888, -87.706 41.884)))"
    )
  end

  let!(:area_a) { create(:area, ward: 33, number: 13, shortcode: "W33A13", slug: "ward-33-sweep-area-13", shape: shape_a) }
  let!(:area_b) { create(:area, ward: 33, number: 14, shortcode: "W33A14", slug: "ward-33-sweep-area-14", shape: shape_b) }

  before do
    allow_any_instance_of(ReverseGeocodeAddress).to receive(:call).and_return("123 N Fake St, Chicago, IL 60618")
  end

  describe "#call" do
    context "when the point is near the shared edge (within 350 ft)" do
      # Point inside area_a, very close to the eastern boundary at -87.706
      let(:lat) { 41.886 }
      let(:lng) { -87.70605 }

      subject { described_class.new(area: area_a, lat: lat, lng: lng) }

      it "returns neighboring areas" do
        results = subject.call
        expect(results).not_to be_empty
        expect(results.first.area.object).to eq(area_b)
      end

      it "includes distance in feet" do
        results = subject.call
        expect(results.first.distance_feet).to be_a(Integer)
        expect(results.first.distance_feet).to be > 0
      end

      it "includes a compass direction" do
        results = subject.call
        expect(FindAdjacentSweepAreas::COMPASS_POINTS).to include(results.first.direction)
      end

      it "includes the reverse-geocoded address" do
        results = subject.call
        expect(results.first.nearest_address).to eq("123 N Fake St, Chicago, IL 60618")
      end
    end

    context "when the point is far from any edge (interior)" do
      # Point in the center of area_a
      let(:lat) { 41.886 }
      let(:lng) { -87.708 }

      subject { described_class.new(area: area_a, lat: lat, lng: lng) }

      it "returns an empty array" do
        expect(subject.call).to eq([])
      end
    end

    context "when there are more than MAX_NEIGHBORS neighbors all within range" do
      # Layout (all touching at lat=41.8838, with user near area_a's SE corner):
      #
      #   [    area_a    ][    area_b    ]
      #   [south_strip   ][east_strip    ]
      #   [corner_sw     ][corner_se     ]
      #
      # Plus area_b (outer let!) sits east of area_a. With the user at
      # (lng=-87.7061, lat=41.8841) (just inside area_a near the SE corner),
      # area_b, south_strip, east_strip, corner_se, and corner_sw are all
      # within the 350-ft threshold, so we expect MAX_NEIGHBORS=3 results
      # back. `far_away` sits ~4km east and must be excluded by the
      # distance filter regardless of how MAX_NEIGHBORS is tuned.
      let(:shape_south_strip) do
        factory.parse_wkt(
          "MULTIPOLYGON (((-87.710 41.8838, -87.706 41.8838, -87.706 41.884, -87.710 41.884, -87.710 41.8838)))"
        )
      end
      let(:shape_east_strip) do
        factory.parse_wkt(
          "MULTIPOLYGON (((-87.706 41.8838, -87.702 41.8838, -87.702 41.884, -87.706 41.884, -87.706 41.8838)))"
        )
      end
      let(:shape_corner_sw) do
        factory.parse_wkt(
          "MULTIPOLYGON (((-87.710 41.882, -87.706 41.882, -87.706 41.8838, -87.710 41.8838, -87.710 41.882)))"
        )
      end
      let(:shape_corner_se) do
        factory.parse_wkt(
          "MULTIPOLYGON (((-87.706 41.882, -87.702 41.882, -87.702 41.8838, -87.706 41.8838, -87.706 41.882)))"
        )
      end
      let(:shape_far_away) do
        # ~4km east of the search point — well beyond EDGE_THRESHOLD_FEET (350ft).
        factory.parse_wkt(
          "MULTIPOLYGON (((-87.660 41.884, -87.656 41.884, -87.656 41.888, -87.660 41.888, -87.660 41.884)))"
        )
      end

      let!(:south_strip) { create(:area, ward: 33, number: 15, shortcode: "W33A15", slug: "ward-33-sweep-area-15", shape: shape_south_strip) }
      let!(:east_strip) { create(:area, ward: 33, number: 16, shortcode: "W33A16", slug: "ward-33-sweep-area-16", shape: shape_east_strip) }
      let!(:corner_sw) { create(:area, ward: 33, number: 17, shortcode: "W33A17", slug: "ward-33-sweep-area-17", shape: shape_corner_sw) }
      let!(:corner_se) { create(:area, ward: 33, number: 18, shortcode: "W33A18", slug: "ward-33-sweep-area-18", shape: shape_corner_se) }
      let!(:far_away) { create(:area, ward: 33, number: 19, shortcode: "W33A19", slug: "ward-33-sweep-area-19", shape: shape_far_away) }

      let(:lat) { 41.8841 }
      let(:lng) { -87.7061 }

      subject { described_class.new(area: area_a, lat: lat, lng: lng) }

      it "returns exactly MAX_NEIGHBORS results, ordered by distance" do
        results = subject.call

        expect(results.length).to eq(FindAdjacentSweepAreas::MAX_NEIGHBORS)
        expect(results.map(&:distance_feet)).to eq(results.map(&:distance_feet).sort)
      end

      it "excludes areas farther than EDGE_THRESHOLD_FEET regardless of MAX_NEIGHBORS" do
        results = subject.call
        result_ids = results.map { |n| n.area.object.id }

        expect(result_ids).not_to include(far_away.id)
      end
    end

    context "when reverse geocoding fails" do
      let(:lat) { 41.886 }
      let(:lng) { -87.70605 }

      subject { described_class.new(area: area_a, lat: lat, lng: lng) }

      before do
        allow_any_instance_of(ReverseGeocodeAddress).to receive(:call).and_return(nil)
      end

      it "still returns the neighbor without an address" do
        results = subject.call
        expect(results).not_to be_empty
        expect(results.first.nearest_address).to be_nil
      end
    end
  end

  describe "#initialize" do
    it "accepts string coordinates and coerces them to floats" do
      service = described_class.new(area: area_a, lat: "41.886", lng: "-87.706")
      expect(service.call).to be_an(Array)
    end

    it "raises ArgumentError for non-numeric lat" do
      expect { described_class.new(area: area_a, lat: "not_a_number", lng: "-87.706") }
        .to raise_error(ArgumentError)
    end

    it "raises ArgumentError for non-numeric lng" do
      expect { described_class.new(area: area_a, lat: "41.886", lng: "oops") }
        .to raise_error(ArgumentError)
    end
  end

  describe "#azimuth_to_compass" do
    subject { described_class.new(area: area_a, lat: 41.886, lng: -87.70605) }

    # 0°=N, 90°=E, 180°=S, 270°=W. Tests the rounding boundary at the
    # midpoint between compass directions (every 22.5°). Ruby's
    # Float#round defaults to half-away-from-zero, so all the .5
    # midpoints below round clockwise (toward the next-larger compass
    # index).
    {
      0 => "N",
      22.4 => "N",
      22.6 => "NE",
      45 => "NE",
      67.5 => "E", # midpoint NE↔E; rounds clockwise to E
      90 => "E",
      112.5 => "SE", # midpoint E↔SE; rounds clockwise to SE
      135 => "SE",
      157.5 => "S", # midpoint SE↔S; rounds clockwise to S
      180 => "S",
      202.5 => "SW", # midpoint S↔SW; rounds clockwise to SW
      225 => "SW",
      247.5 => "W", # midpoint SW↔W; rounds clockwise to W
      270 => "W",
      292.5 => "NW", # midpoint W↔NW; rounds clockwise to NW
      315 => "NW",
      337.4 => "NW",
      337.5 => "N", # midpoint NW↔N; rounds clockwise (and wraps) to N
      337.6 => "N",
      359.9 => "N"
    }.each do |degrees, expected|
      it "maps #{degrees}° to #{expected}" do
        expect(subject.send(:azimuth_to_compass, degrees)).to eq(expected)
      end
    end

    it "defaults to N when azimuth is nil" do
      expect(subject.send(:azimuth_to_compass, nil)).to eq("N")
    end
  end
end
