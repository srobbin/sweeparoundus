require "rails_helper"

RSpec.describe "Search", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  let!(:area) { create(:area) }

  describe "GET /search" do
    context "with coordinates inside an area" do
      it "redirects to the area page" do
        get "/search", params: { lat: 41.885, lng: -87.712, address: "123 Main St" }

        expect(response).to redirect_to(area_path(area))
      end

      it "stores search params in the session" do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }

        expect(session[:search_lat]).to eq(41.885)
        expect(session[:search_lng]).to eq(-87.712)
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
      it "redirects to root with an error" do
        get "/search", params: { lat: 42.0, lng: -87.5, address: "456 Elm St" }

        expect(response).to redirect_to(root_path)
        expect(flash[:error]).to eq("Sorry, we could not find the sweep area associated with your address.")
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
