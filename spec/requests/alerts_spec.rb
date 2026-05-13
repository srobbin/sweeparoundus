require "rails_helper"

RSpec.describe "Alerts", type: :request do
  include JwtHelper

  let!(:area) { create(:area) }
  let(:valid_email) { "test@example.com" }

  # SearchController geocodes server-side, so any test that hits
  # `GET /search` needs the geocoder stubbed.
  before do
    allow(GeocodeAddress).to receive(:new).and_return(
      instance_double(GeocodeAddress,
                      call: GeocodeAddress::Result.new(lat: 41.885, lng: -87.712))
    )
  end

  describe "POST /areas/:area_id/alerts" do
    context "with a valid email" do
      it "creates an alert for the area" do
        expect {
          post area_alerts_path(area), params: { email: valid_email }
        }.to change(Alert, :count).by(1)

        alert = Alert.last
        expect(alert.email).to eq(valid_email)
        expect(alert.area).to eq(area)
      end

      it "enqueues a confirmation email" do
        mailer_dbl = double
        allow(AlertMailer).to receive(:with).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:confirm).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:deliver_later)

        post area_alerts_path(area), params: { email: valid_email }

        expect(AlertMailer).to have_received(:with).with(alert: Alert.last)
        expect(mailer_dbl).to have_received(:confirm)
        expect(mailer_dbl).to have_received(:deliver_later)
      end

      it "redirects to the area page" do
        post area_alerts_path(area), params: { email: valid_email }

        expect(response).to redirect_to(area_path(area))
      end

      it "normalizes email to lowercase and stripped" do
        post area_alerts_path(area), params: { email: "  Test@Example.COM  " }

        expect(Alert.last.email).to eq("test@example.com")
      end
    end

    context "with an invalid email" do
      it "does not create an alert" do
        expect {
          post area_alerts_path(area), params: { email: "not-an-email" }
        }.not_to change(Alert, :count)
      end
    end

    context "with street address saving enabled" do
      before do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }
      end

      it "stores the street address and coordinates on the alert" do
        post area_alerts_path(area), params: {
          email: valid_email,
          is_save_street_address: "1"
        }

        alert = Alert.last
        expect(alert.street_address).to eq("123 Main St")
        expect(alert.lat.to_f).to be_within(0.001).of(41.885)
        expect(alert.lng.to_f).to be_within(0.001).of(-87.712)
      end
    end

    context "with street address saving disabled" do
      before do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }
      end

      it "does not store street address on the alert" do
        post area_alerts_path(area), params: {
          email: valid_email,
          is_save_street_address: "0"
        }

        alert = Alert.last
        expect(alert.street_address).to be_nil
        expect(alert.lat).to be_nil
        expect(alert.lng).to be_nil
      end
    end

    context "subscribing to an adjacent area (search point outside the area being subscribed to)" do
      let!(:other_area) do
        shape = RGeo::Geos.factory(srid: 0).parse_wkt(
          "MULTIPOLYGON (((-87.69 41.86, -87.69 41.87, -87.68 41.87, -87.68 41.86, -87.69 41.86)))"
        )
        create(:area, ward: 28, number: 8, shortcode: "W28A8", slug: "ward-28-sweep-area-8", shape: shape)
      end

      before do
        get "/search", params: { lat: "41.885", lng: "-87.712", address: "123 Main St" }
      end

      it "re-renders the form via Turbo Stream with the adjacent-area warning and no save-address checkbox" do
        post area_alerts_path(other_area),
          params: { email: valid_email, from_neighbor: 1 },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("subscription to notifications for this adjacent area")
        expect(response.body).not_to include("Save my street address")
      end

      it "does not save the street address even if the form param is forced" do
        post area_alerts_path(other_area), params: {
          email: valid_email,
          from_neighbor: 1,
          is_save_street_address: "1"
        }

        alert = Alert.last
        expect(alert.street_address).to be_nil
        expect(alert.lat).to be_nil
        expect(alert.lng).to be_nil
      end
    end

    context "with a duplicate subscription" do
      before do
        create(:alert, area: area, email: valid_email, street_address: nil, lat: nil, lng: nil)
      end

      it "finds the existing alert instead of creating a new one" do
        expect {
          post area_alerts_path(area), params: { email: valid_email }
        }.not_to change(Alert, :count)
      end
    end
  end

  describe "GET /areas/:area_id/alerts/unsubscribe" do
    let!(:alert) { create(:alert, :confirmed, area: area) }

    context "with a valid token" do
      let(:token) { encode_jwt(alert.email, alert.street_address) }

      it "destroys the alert" do
        expect {
          get unsubscribe_area_alerts_path(area), params: { t: token }
        }.to change(Alert, :count).by(-1)
      end

      it "renders the unsubscribe page" do
        get unsubscribe_area_alerts_path(area), params: { t: token }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("You have been unsubscribed")
      end
    end

    context "with a token for a non-existent alert" do
      let(:token) { encode_jwt("nobody@example.com", nil) }

      it "does not raise an error" do
        expect {
          get unsubscribe_area_alerts_path(area), params: { t: token }
        }.not_to raise_error
      end

      it "does not change the alert count" do
        expect {
          get unsubscribe_area_alerts_path(area), params: { t: token }
        }.not_to change(Alert, :count)
      end
    end

    context "with an invalid token" do
      it "renders the invalid link page" do
        get unsubscribe_area_alerts_path(area), params: { t: "invalid.token.here" }

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("This link is invalid or has expired")
      end
    end

    context "with no token" do
      it "renders the invalid link page" do
        get unsubscribe_area_alerts_path(area)

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("This link is invalid or has expired")
      end
    end

    context "with a manage token" do
      let(:token) { encode_manage_jwt(valid_email) }

      it "renders the invalid link page" do
        get unsubscribe_area_alerts_path(area), params: { t: token }

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("This link is invalid or has expired")
      end
    end
  end

  describe "GET /areas/:area_id/alerts/confirm" do
    let!(:alert) { create(:alert, :unconfirmed, area: area) }

    context "with a valid token" do
      let(:token) { encode_jwt(alert.email, alert.street_address) }

      it "confirms the alert" do
        get confirm_area_alerts_path(area), params: { t: token }

        expect(alert.reload.confirmed).to be true
      end

      it "renders the confirmation page" do
        get confirm_area_alerts_path(area), params: { t: token }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Thank you for confirming your subscription")
      end
    end

    context "with a token for a non-existent alert" do
      let(:token) { encode_jwt("nobody@example.com", nil) }

      it "renders the page without an error" do
        get confirm_area_alerts_path(area), params: { t: token }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("could not find your subscription")
      end
    end

    context "with an invalid token" do
      it "renders the invalid link page" do
        get confirm_area_alerts_path(area), params: { t: "invalid.token.here" }

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("This link is invalid or has expired")
      end
    end

    context "with no token" do
      it "renders the invalid link page" do
        get confirm_area_alerts_path(area)

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("This link is invalid or has expired")
      end
    end

    context "with a manage token" do
      let(:token) { encode_manage_jwt(valid_email) }

      it "renders the invalid link page" do
        get confirm_area_alerts_path(area), params: { t: token }

        expect(response).to have_http_status(:bad_request)
        expect(response.body).to include("This link is invalid or has expired")
      end
    end
  end
end
