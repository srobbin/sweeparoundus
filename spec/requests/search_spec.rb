require "rails_helper"

RSpec.describe "Search", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:area) { create(:area) }

  # Default coords the stubbed geocoder returns. Matches the form lat/lng
  # in most tests; the mismatched-coords case is tested separately below.
  let(:geocoded_lat) { 41.885 }
  let(:geocoded_lng) { -87.712 }

  describe "GET /search" do
    before do
      allow(GeocodeAddress).to receive(:new).and_return(
        instance_double(GeocodeAddress,
                        call: GeocodeAddress::Result.new(lat: geocoded_lat, lng: geocoded_lng))
      )
    end

    context "with coordinates inside an area" do
      it "redirects to the area page" do
        get "/search", params: { lat: 41.885, lng: -87.712, address: "123 Main St" }

        expect(response).to redirect_to(area_path(area))
      end

      it "stores search params in the session" do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }

        expect(session[:search_lat]).to eq(geocoded_lat)
        expect(session[:search_lng]).to eq(geocoded_lng)
        expect(session[:search_area_id]).to eq(area.id)
        expect(session[:street_address]).to eq("123 Main St")
      end

      it "stamps the search time so SearchContext can expire stale sessions" do
        freeze_time do
          get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }

          expect(session[:search_set_at]).to eq(Time.current.to_i)
        end
      end
    end

    context "with coordinates outside any area" do
      let(:geocoded_lat) { 42.0 }
      let(:geocoded_lng) { -87.5 }

      it "redirects to root with an error" do
        get "/search", params: { lat: 42.0, lng: -87.5, address: "456 Elm St" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Sorry, we could not find the sweep area associated with your address.")
      end
    end

    context "when the server-side geocoder returns nil" do
      before do
        allow(GeocodeAddress).to receive(:new).and_return(
          instance_double(GeocodeAddress, call: nil)
        )
      end

      it "redirects to root with an error" do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "junk" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("could not locate that address")
      end

      it "does not write search session keys" do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "junk" }

        expect(session[:search_area_id]).to be_nil
        expect(session[:search_lat]).to be_nil
      end
    end

    context "when the client lat/lng disagrees with the server geocode" do
      # The browser's coords don't match the address. The session should
      # store the server-geocoded coords, not the client-supplied ones.
      it "stores the geocoded coordinates in the session" do
        get "/search", params: { lat: "41.95593", lng: "-87.693286", address: "2101 N Rockwell" }

        expect(session[:search_lat]).to eq(geocoded_lat)
        expect(session[:search_lng]).to eq(geocoded_lng)
      end
    end

    context "when the address param is blank" do
      it "redirects to root with a geocode error" do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "   " }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("could not locate that address")
      end
    end

    context "when the address param is missing" do
      it "redirects to root with a geocode error" do
        get "/search", params: { lat: "41.885", lng: "-87.712" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to include("could not locate that address")
      end
    end

    context "with missing coordinates" do
      it "redirects to root when lat is missing" do
        get "/search", params: { lng: -87.712, address: "123 Main St" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Please enter an address to search.")
      end

      it "redirects to root when lng is missing" do
        get "/search", params: { lat: 41.885, address: "123 Main St" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Please enter an address to search.")
      end

      it "redirects to root when both are missing" do
        get "/search", params: { address: "123 Main St" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Please enter an address to search.")
      end
    end
  end
end
