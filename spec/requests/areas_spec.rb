require "rails_helper"

RSpec.describe "Areas", type: :request do
  let!(:area) { create(:area) }
  let(:today) { Time.current.to_date }

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

    context "with an invalid area ID" do
      it "returns 404" do
        get "/areas/nonexistent-area"

        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
