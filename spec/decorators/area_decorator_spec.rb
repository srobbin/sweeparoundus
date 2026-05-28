require "rails_helper"

RSpec.describe AreaDecorator do
  let(:area) { create(:area) }
  let(:decorated_area) { area.decorate }
  let(:today) { Time.current.to_date }

  def map_url_from(image_tag)
    image_tag[/src="([^"]+)"/, 1]
  end

  describe "#map_image" do
    it "returns an <img> tag with a Google Static Maps URL" do
      expect(decorated_area.map_image).to match(/<img.+src="https:\/\/maps\.googleapis\.com\/maps\/api\/staticmap/)
    end

    it "encodes a path query parameter from the simplified polygon" do
      url = map_url_from(decorated_area.map_image)

      expect(url).to include("path=color:0x00000000|weight:5|fillcolor:0xAA000033")
      expect(url).to match(/path=[^&]+\|41\./)
    end

    it "stays under Google's 16,384-character URL limit even for a complex polygon" do
      url = map_url_from(decorated_area.map_image)

      expect(url.length).to be < 16_384
    end

    it "includes the area name in the alt attribute" do
      expect(decorated_area.map_image).to include(%(alt="Sweep area map for #{area.name}"))
    end

    context "when show_marker is false (default)" do
      let(:decorated_area) do
        area.decorate(session: { search_lat: 41.886, search_lng: -87.706 })
      end

      it "does not include a markers parameter" do
        url = map_url_from(decorated_area.map_image)

        expect(url).not_to include("markers=")
      end
    end

    context "when show_marker is true and session has search coordinates" do
      let(:decorated_area) do
        area.decorate(session: { search_lat: 41.886, search_lng: -87.706 })
      end

      it "includes a markers parameter at the searched coordinates" do
        url = map_url_from(decorated_area.map_image(show_marker: true))

        expect(url).to include("markers=|41.886,-87.706|")
      end
    end

    context "when show_marker is true but the session has no search coordinates" do
      it "omits the markers parameter rather than emitting an empty marker" do
        url = map_url_from(decorated_area.map_image(show_marker: true))

        expect(url).not_to include("markers=")
      end
    end

    context "caching the simplified path" do
      let(:memory_cache) { ActiveSupport::Cache::MemoryStore.new }

      before do
        allow(Rails).to receive(:cache).and_return(memory_cache)
      end

      it "caches the path string and reuses it on the next call" do
        allow(area.shape).to receive(:simplify).and_call_original

        decorated_area.map_image
        decorated_area.map_image

        expect(area.shape).to have_received(:simplify).once
      end

      it "busts the cache when updated_at changes" do
        decorated_area.map_image
        original_key = "area_map_path:#{area.id}:#{area.updated_at.to_i}"
        expect(memory_cache.read(original_key)).to be_present

        area.update_column(:updated_at, 1.minute.from_now)
        new_key = "area_map_path:#{area.id}:#{area.reload.updated_at.to_i}"
        expect(memory_cache.read(new_key)).to be_nil
      end

      it "produces the same URL from cache as from a fresh computation" do
        fresh_url = map_url_from(decorated_area.map_image)
        cached_url = map_url_from(decorated_area.map_image)

        expect(cached_url).to eq(fresh_url)
      end
    end

    context "when simplification cannot get the path under budget" do
      it "falls back to the original first ring instead of raising" do
        empty = RGeo::Geos.factory(srid: 0).parse_wkt("POLYGON EMPTY")
        allow(area.shape).to receive(:simplify).and_return(empty)

        expect { decorated_area.map_image }.not_to raise_error
        expect(decorated_area.map_image).to include("<img")
      end

      it "renders an image with no path when the underlying shape has no usable polygon" do
        empty_multi = RGeo::Geos.factory(srid: 0).parse_wkt("MULTIPOLYGON EMPTY")
        allow(area).to receive(:shape).and_return(empty_multi)

        expect { decorated_area.map_image }.not_to raise_error
        url = map_url_from(decorated_area.map_image)
        # No polygon points appended after the path style preamble.
        expect(url).to match(/path=color:0x00000000\|weight:5\|fillcolor:0xAA000033&/)
      end
    end
  end

  describe "#map_coordinates_json" do
    it "returns a JSON array of [lat, lng] pairs from the simplified polygon" do
      json = decorated_area.map_coordinates_json
      coords = JSON.parse(json)

      expect(coords).to be_an(Array)
      expect(coords).not_to be_empty
      expect(coords.first).to match([ a_value_between(41.0, 42.0), a_value_between(-88.0, -87.0) ])
    end

    it "returns lat/lng order (not lng/lat)" do
      coords = JSON.parse(decorated_area.map_coordinates_json)
      lat, lng = coords.first

      expect(lat).to be > 0
      expect(lng).to be < 0
    end

    it "returns an empty JSON array when the shape has no usable polygon" do
      empty_multi = RGeo::Geos.factory(srid: 0).parse_wkt("MULTIPOLYGON EMPTY")
      allow(area).to receive(:shape).and_return(empty_multi)

      expect(decorated_area.map_coordinates_json).to eq("[]")
    end
  end

  describe "#next_sweep" do
    context "with an upcoming sweep with multiple dates" do
      before do
        create(:sweep, area: area, date_1: today + 10, date_2: today + 11, date_3: today + 12, date_4: nil)
      end

      it "returns formatted dates separated by slashes" do
        result = decorated_area.next_sweep

        expect(result).to include((today + 10).strftime("%B %-d"))
        expect(result).to include((today + 11).strftime("%B %-d"))
        expect(result).to include((today + 12).strftime("%B %-d"))
        expect(result).to include(" / ")
      end

      it "excludes nil dates" do
        result = decorated_area.next_sweep
        date_parts = result.split(" / ")

        expect(date_parts.length).to eq(3)
      end
    end

    context "with no upcoming sweeps" do
      it "returns the fallback message" do
        expect(decorated_area.next_sweep).to eq("No sweeps scheduled in the near future.")
      end
    end

    context "with a single-date sweep" do
      before { create(:sweep, area: area, date_1: today + 5, date_2: nil, date_3: nil, date_4: nil) }

      it "returns a single formatted date" do
        result = decorated_area.next_sweep

        expect(result).to eq((today + 5).strftime("%B %-d"))
        expect(result).not_to include("/")
      end
    end
  end

  describe "#max_cluster_size" do
    it "returns 2 when the area has no sweeps" do
      expect(decorated_area.max_cluster_size).to eq(2)
    end

    it "returns 2 for the common case of two-date pairs" do
      create(:sweep, area: area, date_1: today + 1, date_2: today + 2, date_3: nil, date_4: nil)
      create(:sweep, area: area, date_1: today + 8, date_2: today + 9, date_3: nil, date_4: nil)

      expect(decorated_area.max_cluster_size).to eq(2)
    end

    it "returns 4 when at least one cluster fills all four columns" do
      create(:sweep, area: area, date_1: today + 1, date_2: today + 2, date_3: nil, date_4: nil)
      create(:sweep, area: area, date_1: today + 8, date_2: today + 9, date_3: today + 10, date_4: today + 11)

      expect(decorated_area.max_cluster_size).to eq(4)
    end

    it "returns 2 (not 1) when the only sweep is a singleton, to keep a sensible default table width" do
      create(:sweep, area: area, date_1: today + 1, date_2: nil, date_3: nil, date_4: nil)

      expect(decorated_area.max_cluster_size).to eq(2)
    end

    it "reflects the largest cluster, not the most recent one" do
      create(:sweep, area: area, date_1: today + 1, date_2: today + 2, date_3: today + 3, date_4: nil)
      create(:sweep, area: area, date_1: today + 8, date_2: today + 9, date_3: nil, date_4: nil)

      expect(decorated_area.max_cluster_size).to eq(3)
    end
  end
end
