require "rails_helper"

RSpec.describe "Areas", type: :request do
  let!(:area) { create(:area) }
  let(:today) { Time.current.to_date }

  # SearchController geocodes server-side, so any test that hits
  # `GET /search` needs the geocoder stubbed.
  before do
    allow(GeocodeAddress).to receive(:new).and_return(
      instance_double(GeocodeAddress,
                      call: GeocodeAddress::Result.new(lat: 41.885, lng: -87.712))
    )
  end

  describe "GET /areas/:id" do
    context "HTML format" do
      it "renders the area show page" do
        get area_path(area)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(area.name)
      end

      it "includes the next sweep info" do
        create(:sweep, area: area, date_1: today + 10)
        get area_path(area)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include((today + 10).strftime("%B %-d"))
      end

      it "shows fallback when no sweeps are scheduled" do
        get area_path(area)

        expect(response.body).to include("No sweeps scheduled in the near future")
      end
    end

    context "ICS format" do
      let!(:sweep) do
        create(:sweep, area: area, date_1: today + 10, date_2: today + 11, date_3: nil, date_4: nil)
      end

      it "returns an ICS calendar file" do
        get area_path(area, format: :ics)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("BEGIN:VCALENDAR")
        expect(response.body).to include("END:VCALENDAR")
      end

      it "contains VEVENT entries for each sweep date" do
        get area_path(area, format: :ics)

        expect(response.body).to include("BEGIN:VEVENT")
        expect(response.body).to include("Street Sweeping for Ward 28\\, Sweep Area 7")
        expect(response.body).to include(area.shortcode)
      end

      it "includes the correct dates" do
        get area_path(area, format: :ics)

        expect(response.body).to include((today + 10).strftime("%Y%m%d"))
        expect(response.body).to include((today + 11).strftime("%Y%m%d"))
      end

      it "skips nil dates" do
        get area_path(area, format: :ics)

        events = response.body.scan("BEGIN:VEVENT")
        expect(events.length).to eq(2)
      end

      it "includes calendar metadata" do
        get area_path(area, format: :ics)

        expect(response.body).to include("X-WR-CALNAME:#{ENV["SITE_NAME"]}: Ward 28\\, Sweep Area 7")
        expect(response.body).to include("X-WR-TIMEZONE:America/Chicago")
      end

      it "sets the Content-Disposition header with the filename" do
        get area_path(area, format: :ics)

        filename = "#{ENV["SITE_NAME"].gsub(" ", "")}_#{area.shortcode}.ics"
        expect(response.headers["Content-Disposition"]).to include(filename)
      end
    end

    context "after searching for an address" do
      # These coordinates fall inside the factory area (verified by
      # spec/requests/search_spec.rb). Coordinates that don't fall in
      # any area would cause SearchController to redirect with a flash
      # error and never populate the session, silently breaking these
      # tests.
      let(:search_lat) { "41.885" }
      let(:search_lng) { "-87.712" }
      let(:street_address) { "3324 N California Ave, Chicago, IL 60618" }

      before do
        get "/search", params: { lat: search_lat, lng: search_lng, address: street_address }
        allow_any_instance_of(FindAdjacentSweepAreas).to receive(:call).and_return(stubbed_neighbors)
      end

      context "viewing the area that contains the searched point, with adjacent areas" do
        # Give neighbor_area a distinct shape so it doesn't shadow `area`
        # in the SearchController's ST_Contains lookup (the factory's
        # default shape would otherwise also contain the searched point).
        let(:neighbor_shape) do
          RGeo::Geos.factory(srid: 0).parse_wkt(
            "MULTIPOLYGON (((-87.69 41.86, -87.69 41.87, -87.68 41.87, -87.68 41.86, -87.69 41.86)))"
          )
        end
        let(:neighbor_area) { create(:area, ward: 33, number: 14, shortcode: "W33A14", slug: "ward-33-sweep-area-14", shape: neighbor_shape) }
        let(:stubbed_neighbors) do
          [FindAdjacentSweepAreas::Neighbor.new(
            area: neighbor_area.decorate,
            distance_feet: 42,
            direction: "E",
            nearest_address: "3300 N California Ave, Chicago, IL 60618"
          )]
        end

        it "renders the searched address, neighbors partial, search marker, and save-address checkbox" do
          get area_path(area)

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(street_address)
          expect(response.body).to include("Adjacent Sweep Areas")
          expect(response.body).to include("Ward 33, Sweep Area 14")
          expect(response.body).to include("42 ft E")
          expect(response.body).to include("&amp;markers=|#{search_lat},#{search_lng}|")
          expect(response.body).to include("Save my street address")
          expect(response.body).not_to include("subscription to notifications for this adjacent area")
        end
      end

      context "viewing the area that contains the searched point, with no adjacent areas" do
        let(:stubbed_neighbors) { [] }

        it "does not render the neighbors partial" do
          get area_path(area)

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("Adjacent Sweep Areas")
        end
      end

      context "viewing an area that does not contain the searched point (via neighbor link)" do
        let!(:other_area) do
          shape = RGeo::Geos.factory(srid: 0).parse_wkt(
            "MULTIPOLYGON (((-87.69 41.86, -87.69 41.87, -87.68 41.87, -87.68 41.86, -87.69 41.86)))"
          )
          create(:area, ward: 28, number: 8, shortcode: "W28A8", slug: "ward-28-sweep-area-8", shape: shape)
        end
        let(:stubbed_neighbors) { [] }

        it "renders the adjacent-area warning instead of the save-address checkbox" do
          get area_path(other_area, from_neighbor: 1)

          expect(response).to have_http_status(:ok)
          expect(response.body).to include("subscription to notifications for this adjacent area")
          expect(response.body).not_to include("Save my street address")
          expect(response.body).not_to include("Adjacent Sweep Areas")
        end

        it "shows 'Adjacent sweep area' with the searched address" do
          get area_path(other_area, from_neighbor: 1)

          expect(response.body).to include("Adjacent sweep area (#{street_address})")
        end

        it "does not show adjacent-area context without the from_neighbor param" do
          get area_path(other_area)

          expect(response).to have_http_status(:ok)
          expect(response.body).not_to include("subscription to notifications for this adjacent area")
          expect(response.body).not_to include("Adjacent sweep area")
        end
      end
    end

    context "without search session" do
      it "does not render the searched address, marker, neighbors, or save-address checkbox" do
        get area_path(area)

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Adjacent Sweep Areas")
        expect(response.body).not_to include("subscription to notifications for this adjacent area")
        expect(response.body).not_to include("&amp;markers=")
        expect(response.body).not_to include("Save my street address")
      end
    end

    context "when FindAdjacentSweepAreas raises an error" do
      before do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }
        allow_any_instance_of(FindAdjacentSweepAreas).to receive(:call).and_raise(StandardError, "PostGIS boom")
        allow(Rails.logger).to receive(:error)
      end

      it "still renders the page without neighbors" do
        get area_path(area)

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(area.name)
        expect(response.body).not_to include("Adjacent Sweep Areas")
      end

      it "logs the error" do
        get area_path(area)

        expect(Rails.logger).to have_received(:error).with(/PostGIS boom/)
      end
    end

    context "with a stale search session (older than SEARCH_CONTEXT_TTL)" do
      include ActiveSupport::Testing::TimeHelpers

      it "treats the session as if no search happened and skips the neighbor lookup" do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }
        # Should never be called when the session is stale; if it is,
        # we'll know via this expectation rather than via a flaky DB
        # query result.
        expect(FindAdjacentSweepAreas).not_to receive(:new)

        travel SearchContext::SEARCH_CONTEXT_TTL + 1.minute do
          get area_path(area)
        end

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("123 Main St")
        expect(response.body).not_to include("Adjacent Sweep Areas")
        expect(response.body).not_to include("&amp;markers=")
      end
    end

    context "with an invalid area ID" do
      it "returns 404" do
        get "/areas/nonexistent-area"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
