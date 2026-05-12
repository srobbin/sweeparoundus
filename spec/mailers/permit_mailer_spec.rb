# frozen_string_literal: true

require "rails_helper"

RSpec.describe PermitMailer, type: :mailer do
  include JwtHelper

  let!(:area) { create :area }
  let!(:alert) do
    create :alert, :confirmed, :with_address, area: area,
           lat: 41.94200, lng: -87.69870
  end
  let!(:permit) do
    create :cdot_permit,
      unique_key: "5000001",
      application_status: "Open",
      application_start_date: Time.zone.local(2026, 5, 8, 9, 0, 0),
      application_end_date: Time.zone.local(2026, 5, 9, 17, 0, 0),
      street_number_from: 3300,
      street_number_to: 3350,
      direction: "N",
      street_name: "CALIFORNIA",
      suffix: "AVE",
      work_type_description: "Dumpster",
      application_description: "Building renovation"
  end
  let(:line_from) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }
  let(:line_to)   { GeocodeAddress::Result.new(lat: 41.94284, lng: -87.69870) }
  let(:distance_feet) { 95 }

  let(:matches) do
    [{ permit: permit, distance_feet: distance_feet, line_from: line_from, line_to: line_to }]
  end

  let(:html_body) do
    mail.body.parts.find { |p| p.content_type.match "text/html" }.body.raw_source
  end
  let(:text_body) do
    mail.body.parts.find { |p| p.content_type.match "text/plain" }.body.raw_source
  end

  let(:mail) do
    described_class.with(alert: alert, matches: matches).notify.deliver_now
  end

  around do |example|
    original = ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = "test-key"
    example.run
    ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = original
  end

  describe "#notify email" do
    it "has the right envelope" do
      expect(mail.from).to eq(["info@wethesweeple.com"])
      expect(mail.to).to include(alert.email)
      expect(mail.subject).to eq("Temporary No Parking on California Ave")
    end

    it "includes the segment label, distance, dates, and work info in the HTML body" do
      expect(html_body).to include("3300-3350 N CALIFORNIA AVE")
      expect(html_body).to include("about 95 ft from your address")
      expect(html_body).to include("Friday, May 8")
      expect(html_body).to include("Saturday, May 9")
      expect(html_body).to include("Dumpster")
      expect(html_body).to include("Building renovation")
    end

    it "embeds the static map image with the alert + line endpoints" do
      expect(html_body).to match(/<img [^>]*src="https:\/\/maps\.googleapis\.com\/maps\/api\/staticmap\?[^"]*"/)
      expect(html_body).to include("color%3Ablue%7Clabel%3AH%7C41.942%2C-87.6987")
    end

    it "includes the manage-subscriptions link and no unsubscribe link" do
      expect(html_body).to include("Manage subscriptions")
      expect(html_body).to include(manage_subscriptions_url.to_s)
      expect(html_body).not_to include("Unsubscribe")
      expect(html_body).not_to include(unsubscribe_area_alerts_url(area))
    end

    it "includes the disclaimer" do
      expect(html_body).to include(CGI.escapeHTML(ApplicationMailer::DISCLAIMER))
    end

    it "renders matching content in the text body" do
      expect(text_body).to include("temporary \"No Parking\" signs may be going up")
      expect(text_body).to include("3300-3350 N CALIFORNIA AVE")
      expect(text_body).to include("about 95 ft from your address")
      expect(text_body).to include("Friday, May 8")
      expect(text_body).to include("Manage subscriptions:")
      expect(text_body).not_to include("Unsubscribe:")
    end

    it "embeds a valid manage JWT" do
      token = html_body.match(/subscriptions\/manage\?t=([^"&\s]+)/)[1]
      decoded = decode_manage_jwt(token)

      expect(decoded["sub"]).to eq(alert.email)
      expect(decoded["purpose"]).to eq("manage")
      expect(decoded["exp"]).to be_a(Integer)
    end

    it "uses Arial 10pt typography in the HTML layout" do
      expect(html_body).to include("Arial, Helvetica, sans-serif")
      expect(html_body).to include("10pt")
    end

    context "when the permit's start and end fall on the same day" do
      let!(:permit) do
        create :cdot_permit,
          unique_key: "5000002",
          application_status: "Open",
          application_start_date: Time.zone.local(2026, 5, 8, 9, 0, 0),
          application_end_date: Time.zone.local(2026, 5, 8, 17, 0, 0),
          street_number_from: 3300, street_number_to: 3350,
          direction: "N", street_name: "CALIFORNIA", suffix: "AVE"
      end

      it "renders a single date instead of a range" do
        expect(html_body).to include("Friday, May 8")
        expect(html_body).not_to include("–")
      end
    end

    context "when no static map can be generated" do
      around do |example|
        original = ENV["GOOGLE_MAPS_FRONTEND_API_KEY"]
        ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = ""
        example.run
        ENV["GOOGLE_MAPS_FRONTEND_API_KEY"] = original
      end

      it "renders the email without the map block" do
        expect(html_body).not_to include("staticmap")
        expect(html_body).to include("3300-3350 N CALIFORNIA AVE")
      end
    end

    context "with multiple permits" do
      let!(:second_permit) do
        create :cdot_permit,
          unique_key: "5000099",
          application_status: "Open",
          application_start_date: Time.zone.local(2026, 5, 10, 9, 0, 0),
          application_end_date: Time.zone.local(2026, 5, 10, 17, 0, 0),
          street_number_from: 1500,
          street_number_to: 1550,
          direction: "N",
          street_name: "ASHLAND",
          suffix: "AVE",
          work_type_description: "Crane"
      end

      let(:second_line_from) { GeocodeAddress::Result.new(lat: 41.95000, lng: -87.66700) }
      let(:second_line_to)   { GeocodeAddress::Result.new(lat: 41.95200, lng: -87.66700) }

      let(:matches) do
        [
          { permit: permit, distance_feet: 95, line_from: line_from, line_to: line_to },
          { permit: second_permit, distance_feet: 200, line_from: second_line_from, line_to: second_line_to },
        ]
      end

      it "joins unique street names in the subject" do
        expect(mail.subject).to eq("Temporary No Parking on California Ave, Ashland Ave")
      end

      it "renders all permits in the HTML body" do
        expect(html_body).to include("3300-3350 N CALIFORNIA AVE")
        expect(html_body).to include("1500-1550 N ASHLAND AVE")
        expect(html_body).to include("Permit 1 of 2")
        expect(html_body).to include("Permit 2 of 2")
        expect(html_body).to include("Building renovation")
        expect(html_body).to include("Crane")
      end

      it "renders all permits in the text body" do
        expect(text_body).to include("3300-3350 N CALIFORNIA AVE")
        expect(text_body).to include("1500-1550 N ASHLAND AVE")
        expect(text_body).to include("Permit 1 of 2")
        expect(text_body).to include("Permit 2 of 2")
        expect(text_body).to include("for 2 upcoming City of Chicago permits")
      end

      it "deduplicates the subject when multiple permits hit the same street" do
        matches[1][:permit] = create(:cdot_permit,
          unique_key: "5000100",
          street_number_from: 3500, street_number_to: 3550,
          direction: "N", street_name: "CALIFORNIA", suffix: "AVE")

        expect(mail.subject).to eq("Temporary No Parking on California Ave")
      end
    end
  end
end
