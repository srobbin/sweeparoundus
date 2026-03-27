require "rails_helper"

RSpec.describe "Api::V1::Sweeps", type: :request do
  let!(:area) { create(:area) }
  let(:today) { Time.current.to_date }

  # A point inside the factory area polygon (Ward 28, Sweep Area 7)
  let(:inside_lat) { 41.885 }
  let(:inside_lng) { -87.712 }

  # A point outside any area polygon
  let(:outside_lat) { 42.0 }
  let(:outside_lng) { -87.5 }

  describe "GET /api/v1/sweeps" do
    context "with valid coordinates matching an area" do
      let!(:sweep) do
        create(:sweep, area: area,
               date_1: today + 10, date_2: today + 11,
               date_3: nil, date_4: nil)
      end

      it "returns the area with next sweep data" do
        get "/api/v1/sweeps", params: { lat: inside_lat, lng: inside_lng }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["area"]["name"]).to eq("Ward 28, Sweep Area 7")
        expect(json["area"]["shortcode"]).to eq("W28A7")
        expect(json["area"]["url"]).to eq("http://www.example.com/areas/ward-28-sweep-area-7")
        expect(json["area"]["next_sweep"]["dates"]).to eq([
          (today + 10).iso8601,
          (today + 11).iso8601
        ])
        expect(json["area"]["next_sweep"]["formatted"]).to eq(
          "#{(today + 10).strftime("%B %-d")} / #{(today + 11).strftime("%B %-d")}"
        )
      end
    end

    context "with valid coordinates matching an area but no upcoming sweeps" do
      it "returns the area with null next_sweep" do
        get "/api/v1/sweeps", params: { lat: inside_lat, lng: inside_lng }

        expect(response).to have_http_status(:ok)
        json = response.parsed_body

        expect(json["area"]["name"]).to eq("Ward 28, Sweep Area 7")
        expect(json["area"]["next_sweep"]).to be_nil
      end
    end

    context "with valid coordinates not matching any area" do
      it "returns 404" do
        get "/api/v1/sweeps", params: { lat: outside_lat, lng: outside_lng }

        expect(response).to have_http_status(:not_found)
        json = response.parsed_body
        expect(json["error"]).to eq("No sweep area found for the given coordinates.")
      end
    end

    context "with missing lat" do
      it "returns 422 with param name" do
        get "/api/v1/sweeps", params: { lng: inside_lng }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Missing required parameter: lat")
      end
    end

    context "with missing lng" do
      it "returns 422 with param name" do
        get "/api/v1/sweeps", params: { lat: inside_lat }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Missing required parameter: lng")
      end
    end

    context "with both params missing" do
      it "returns 422 identifying the first missing param" do
        get "/api/v1/sweeps"

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Missing required parameter: lat")
      end
    end

    context "with empty string coordinates" do
      it "returns 422 as missing param" do
        get "/api/v1/sweeps", params: { lat: "", lng: "" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Missing required parameter: lat")
      end
    end

    context "with non-numeric coordinates" do
      it "returns 422" do
        get "/api/v1/sweeps", params: { lat: "abc", lng: "xyz" }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Invalid coordinates.")
      end
    end

    context "with Infinity coordinates" do
      it "returns 422" do
        get "/api/v1/sweeps", params: { lat: "Infinity", lng: inside_lng }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Invalid coordinates.")
      end
    end

    context "with out-of-bounds coordinates" do
      it "returns 422 for lat outside -90..90" do
        get "/api/v1/sweeps", params: { lat: 999, lng: inside_lng }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Invalid coordinates.")
      end

      it "returns 422 for lng outside -180..180" do
        get "/api/v1/sweeps", params: { lat: inside_lat, lng: -500 }

        expect(response).to have_http_status(:unprocessable_entity)
        json = response.parsed_body
        expect(json["error"]).to eq("Invalid coordinates.")
      end
    end

    context "with a four-date sweep" do
      let!(:sweep) do
        create(:sweep, area: area,
               date_1: today + 5, date_2: today + 6,
               date_3: today + 7, date_4: today + 8)
      end

      it "returns all four dates" do
        get "/api/v1/sweeps", params: { lat: inside_lat, lng: inside_lng }

        json = response.parsed_body
        expect(json["area"]["next_sweep"]["dates"].length).to eq(4)
      end
    end

    it "returns JSON content type" do
      get "/api/v1/sweeps", params: { lat: inside_lat, lng: inside_lng }

      expect(response.content_type).to include("application/json")
    end
  end
end
