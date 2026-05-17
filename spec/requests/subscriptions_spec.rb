require "rails_helper"

RSpec.describe "Subscriptions", type: :request do
  include JwtHelper

  let!(:area) { create(:area) }
  let(:email) { "test@example.com" }

  describe "GET /subscriptions" do
    it "renders the email entry form" do
      get subscriptions_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Manage Your Subscriptions")
      expect(response.body).to include("Send me a link")
    end
  end

  describe "POST /subscriptions/send_link" do
    before { Rack::Attack.cache.store.clear }

    context "with a valid email" do
      it "enqueues a manage link email" do
        mailer_dbl = double
        allow(SubscriptionMailer).to receive(:with).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:manage_link).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:deliver_later)

        post subscriptions_send_link_path, params: { email: email }

        expect(SubscriptionMailer).to have_received(:with).with(email: email)
        expect(mailer_dbl).to have_received(:manage_link)
        expect(mailer_dbl).to have_received(:deliver_later)
      end

      it "redirects to subscriptions page with a notice" do
        post subscriptions_send_link_path, params: { email: email }

        expect(response).to redirect_to(subscriptions_path)
        follow_redirect!
        expect(response.body).to include("receive an email")
      end
    end

    context "with an email that has extra whitespace and uppercase" do
      it "normalizes the email before sending" do
        mailer_dbl = double
        allow(SubscriptionMailer).to receive(:with).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:manage_link).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:deliver_later)

        post subscriptions_send_link_path, params: { email: "  Test@Example.COM  " }

        expect(SubscriptionMailer).to have_received(:with).with(email: "test@example.com")
      end
    end

    context "with an invalid email" do
      it "does not send an email" do
        allow(SubscriptionMailer).to receive(:with).and_call_original

        post subscriptions_send_link_path, params: { email: "not-an-email" }

        expect(SubscriptionMailer).not_to have_received(:with)
      end

      it "still shows the same confirmation message" do
        post subscriptions_send_link_path, params: { email: "not-an-email" }

        expect(response).to redirect_to(subscriptions_path)
      end
    end

    context "with a missing email param" do
      it "does not send an email" do
        allow(SubscriptionMailer).to receive(:with).and_call_original

        post subscriptions_send_link_path

        expect(SubscriptionMailer).not_to have_received(:with)
      end

      it "still shows the same confirmation message" do
        post subscriptions_send_link_path

        expect(response).to redirect_to(subscriptions_path)
        follow_redirect!
        expect(response.body).to include("receive an email")
      end
    end
  end

  describe "GET /subscriptions/manage" do
    context "with a valid token" do
      let(:token) { encode_manage_jwt(email) }

      it "renders the manage page" do
        get manage_subscriptions_path, params: { t: token }

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Your subscriptions")
        expect(response.body).to include(email)
      end

      context "with confirmed and unconfirmed alerts" do
        let!(:confirmed_alert) { create(:alert, :confirmed, :with_address, email: email, area: area) }
        let!(:unconfirmed_alert) { create(:alert, :unconfirmed, :with_address, email: email, area: area) }

        it "shows all alerts" do
          get manage_subscriptions_path, params: { t: token }

          expect(response.body).to include(confirmed_alert.street_address)
          expect(response.body).to include(unconfirmed_alert.street_address)
        end

        it "shows status indicators" do
          get manage_subscriptions_path, params: { t: token }

          expect(response.body).to include("Active")
          expect(response.body).to include("Pending")
        end
      end

      context "with only unconfirmed alerts" do
        let!(:pending_alert) { create(:alert, :unconfirmed, :with_address, email: email, area: area) }

        it "shows the pending section and the 'no active subscriptions' message" do
          get manage_subscriptions_path, params: { t: token }

          expect(response.body).to include("Needs your attention")
          expect(response.body).to include(pending_alert.street_address)
          expect(response.body).to include("No active subscriptions yet")
          expect(response.body).not_to include("empty-state")
        end
      end

      context "with no alerts" do
        it "shows the empty state" do
          get manage_subscriptions_path, params: { t: token }

          expect(response.body).to include("You don't have any subscriptions yet")
        end
      end

      context "with an alert whose area has been deleted" do
        let!(:orphaned_alert) { create(:alert, :confirmed, :with_address, email: email, area: nil) }

        it "shows the alert without crashing" do
          get manage_subscriptions_path, params: { t: token }

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(orphaned_alert.street_address)
          expect(response.body).to include("Area no longer available")
        end
      end
    end

    context "with an expired token" do
      let(:token) do
        payload = { sub: email, purpose: "manage", exp: 1.hour.ago.to_i }
        JWT.encode(payload, ENV["SECRET_KEY_JWT"], "HS256")
      end

      it "redirects to subscriptions page with an error" do
        get manage_subscriptions_path, params: { t: token }

        expect(response).to redirect_to(subscriptions_path)
        follow_redirect!
        expect(response.body).to include("Your link has expired")
      end
    end

    context "with an invalid token" do
      it "redirects to subscriptions page with an error" do
        get manage_subscriptions_path, params: { t: "invalid.token.here" }

        expect(response).to redirect_to(subscriptions_path)
        follow_redirect!
        expect(response.body).to include("Invalid link")
      end
    end

    context "with a non-manage token" do
      let(:token) { encode_jwt(email, "123 Main St") }

      it "redirects to subscriptions page with an error" do
        get manage_subscriptions_path, params: { t: token }

        expect(response).to redirect_to(subscriptions_path)
        follow_redirect!
        expect(response.body).to include("Invalid link")
      end
    end
  end

  describe "POST /subscriptions" do
    let(:token) { encode_manage_jwt(email) }
    let(:lat) { "41.885" }
    let(:lng) { "-87.712" }
    let(:address) { "123 Main St" }

    context "with valid coordinates in a sweep area" do
      before do
        allow(Area).to receive(:find_by_coordinates).with(lat, lng).and_return(area)
      end

      it "creates a confirmed alert" do
        expect {
          post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }
        }.to change(Alert, :count).by(1)

        alert = Alert.last
        expect(alert.email).to eq(email)
        expect(alert.area).to eq(area)
        expect(alert.street_address).to eq(address)
        expect(alert.confirmed).to be true
      end

      it "redirects back to the manage page" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
      end

      it "returns turbo_stream with the updated subscriptions list and flash" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include("subscriptions-wrapper")
        expect(response.body).to include(address)
        expect(response.body).to include("Subscription added")
        expect(response.body).to include("add-subscription-flash")
      end

      it "no longer renders the empty-state element after the first subscription is added" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).not_to include("empty-state")
      end

      context "with a duplicate subscription" do
        before do
          create(:alert, :confirmed, email: email, area: area, street_address: address, lat: lat, lng: lng)
        end

        it "does not create a duplicate" do
          expect {
            post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }
          }.not_to change(Alert, :count)
        end
      end

      context "with an existing unconfirmed subscription at the same address" do
        let!(:existing_alert) { create(:alert, :unconfirmed, email: email, area: area, street_address: address, lat: lat, lng: lng) }

        it "re-confirms the existing alert without creating a new one" do
          expect {
            post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }
          }.not_to change(Alert, :count)

          expect(existing_alert.reload.confirmed).to be true
        end
      end
    end

    context "when a race condition causes RecordNotUnique" do
      before do
        allow(Area).to receive(:find_by_coordinates).with(lat, lng).and_return(area)
        allow_any_instance_of(Alert).to receive(:save).and_raise(ActiveRecord::RecordNotUnique)
      end

      it "handles the race condition gracefully" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("You already have a subscription for this address")
      end
    end

    context "when save fails unexpectedly" do
      before do
        allow(Area).to receive(:find_by_coordinates).with(lat, lng).and_return(area)
        allow_any_instance_of(Alert).to receive(:save).and_return(false)
      end

      it "does not create an alert" do
        expect {
          post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }
        }.not_to change(Alert, :count)
      end

      it "shows a generic error" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("Could not create subscription")
      end
    end

    context "with coordinates outside any sweep area" do
      before do
        allow(Area).to receive(:find_by_coordinates).and_return(nil)
      end

      it "does not create an alert" do
        expect {
          post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }
        }.not_to change(Alert, :count)
      end

      it "shows an error" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("could not find the sweep area")
      end
    end

    context "with a blank address" do
      it "does not create an alert" do
        expect {
          post create_subscription_path, params: { t: token, address: "  ", lat: lat, lng: lng }
        }.not_to change(Alert, :count)
      end

      it "shows an error" do
        post create_subscription_path, params: { t: token, address: "", lat: lat, lng: lng }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("enter an address")
      end
    end

    context "without coordinates" do
      it "does not create an alert" do
        expect {
          post create_subscription_path, params: { t: token, address: address }
        }.not_to change(Alert, :count)
      end

      it "shows an error" do
        post create_subscription_path, params: { t: token, address: address }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("select an address from the suggestions")
      end
    end

    context "with an expired token" do
      let(:token) do
        payload = { sub: email, purpose: "manage", exp: 1.hour.ago.to_i }
        JWT.encode(payload, ENV["SECRET_KEY_JWT"], "HS256")
      end

      it "redirects to subscriptions page" do
        post create_subscription_path, params: { t: token, address: address, lat: lat, lng: lng }

        expect(response).to redirect_to(subscriptions_path)
      end
    end
  end

  describe "PATCH /subscriptions/:id" do
    let(:token) { encode_manage_jwt(email) }
    let!(:alert) do
      create(:alert, :confirmed, :with_address, email: email, area: area,
             permit_notifications: true)
    end

    context "with a valid token" do
      it "turns permit_notifications off when '0' is submitted" do
        patch update_subscription_path(alert, t: token), params: { permit_notifications: "0" }

        expect(alert.reload.permit_notifications).to be false
      end

      it "turns permit_notifications back on when '1' is submitted" do
        alert.update!(permit_notifications: false)

        patch update_subscription_path(alert, t: token), params: { permit_notifications: "1" }

        expect(alert.reload.permit_notifications).to be true
      end

      it "treats anything other than '1' as off (defensive against unchecked toggles)" do
        patch update_subscription_path(alert, t: token), params: { permit_notifications: "" }

        expect(alert.reload.permit_notifications).to be false
      end

      it "redirects back to the manage page on HTML requests" do
        patch update_subscription_path(alert, t: token), params: { permit_notifications: "0" }

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
      end

      it "returns a turbo_stream that replaces the alert row in place" do
        patch update_subscription_path(alert, t: token),
          params: { permit_notifications: "0" },
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream")
        # update.turbo_stream.erb replaces just the alert row, not the
        # whole wrapper (confirm/destroy do replace the wrapper because
        # they change which section the alert belongs to).
        expect(response.body).to include(ActionView::RecordIdentifier.dom_id(alert))
        expect(response.body).not_to include("subscriptions-wrapper")
        expect(response.body).to include(alert.street_address)
      end
    end

    context "when the alert belongs to a different email" do
      let!(:other_alert) do
        create(:alert, :confirmed, :with_address, email: "other@example.com", area: area,
               permit_notifications: true)
      end

      it "does not update the alert and redirects with an error" do
        patch update_subscription_path(other_alert, t: token), params: { permit_notifications: "0" }

        expect(other_alert.reload.permit_notifications).to be true
        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("Subscription not found")
      end
    end

    context "with a non-existent alert ID" do
      it "redirects with an error" do
        patch update_subscription_path(id: SecureRandom.uuid, t: token),
          params: { permit_notifications: "0" }

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("Subscription not found")
      end
    end

    context "when the update fails at the model layer" do
      before do
        allow_any_instance_of(Alert).to receive(:update).and_return(false)
      end

      it "redirects with a generic error rather than rendering a success turbo_stream" do
        patch update_subscription_path(alert, t: token), params: { permit_notifications: "0" }

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("Could not update subscription")
      end
    end

    context "with an expired token" do
      let(:token) do
        payload = { sub: email, purpose: "manage", exp: 1.hour.ago.to_i }
        JWT.encode(payload, ENV["SECRET_KEY_JWT"], "HS256")
      end

      it "redirects to the subscriptions page without updating the alert" do
        patch update_subscription_path(alert, t: token), params: { permit_notifications: "0" }

        expect(alert.reload.permit_notifications).to be true
        expect(response).to redirect_to(subscriptions_path)
      end
    end

    context "with an invalid token" do
      it "redirects to the subscriptions page without updating the alert" do
        patch update_subscription_path(alert, t: "garbage"), params: { permit_notifications: "0" }

        expect(alert.reload.permit_notifications).to be true
        expect(response).to redirect_to(subscriptions_path)
      end
    end
  end

  describe "PATCH /subscriptions/:id/confirm" do
    let(:token) { encode_manage_jwt(email) }
    let!(:alert) { create(:alert, :unconfirmed, :with_address, email: email, area: area) }

    context "with a valid token" do
      it "confirms the alert" do
        patch confirm_subscription_path(alert, t: token)

        expect(alert.reload.confirmed).to be true
      end

      it "redirects back to the manage page" do
        patch confirm_subscription_path(alert, t: token)

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
      end

      it "returns turbo_stream replacing the alert" do
        patch confirm_subscription_path(alert, t: token),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include(alert.street_address)
      end
    end

    context "when the alert belongs to a different email" do
      let!(:other_alert) { create(:alert, :unconfirmed, email: "other@example.com", area: area) }

      it "does not confirm the alert and redirects" do
        patch confirm_subscription_path(other_alert, t: token)

        expect(other_alert.reload.confirmed).to be false
        expect(response).to redirect_to(manage_subscriptions_path(t: token))
      end
    end

    context "with a non-existent alert ID" do
      it "redirects with an error" do
        patch confirm_subscription_path(id: SecureRandom.uuid, t: token)

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("Could not confirm subscription")
      end
    end
  end

  describe "DELETE /subscriptions/:id" do
    let(:token) { encode_manage_jwt(email) }
    let!(:alert) { create(:alert, :confirmed, :with_address, email: email, area: area) }

    context "with a valid token" do
      it "destroys the alert" do
        expect {
          delete destroy_subscription_path(alert, t: token)
        }.to change(Alert, :count).by(-1)
      end

      it "redirects back to the manage page" do
        delete destroy_subscription_path(alert, t: token)

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
      end

      it "returns turbo_stream replacing the subscriptions list with flash" do
        delete destroy_subscription_path(alert, t: token),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response).to have_http_status(:ok)
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(response.body).to include("turbo-stream")
        expect(response.body).to include("subscriptions-wrapper")
        expect(response.body).to include("Subscription removed")
        expect(response.body).to include("manage-flash")
        expect(response.body).not_to include(alert.street_address)
      end

      it "renders the empty state when the last alert is removed" do
        delete destroy_subscription_path(alert, t: token),
          headers: { "Accept" => "text/vnd.turbo-stream.html" }

        expect(response.body).to include("empty-state")
        expect(response.body).to include("You don't have any subscriptions yet")
      end

      context "when other alerts remain" do
        let!(:other_alert) { create(:alert, :confirmed, :with_address, email: email, area: area) }

        it "does not render the empty state" do
          delete destroy_subscription_path(alert, t: token),
            headers: { "Accept" => "text/vnd.turbo-stream.html" }

          expect(response.body).not_to include("empty-state")
        end
      end
    end

    context "when the alert belongs to a different email" do
      let!(:other_alert) { create(:alert, :confirmed, email: "other@example.com", area: area) }

      it "does not destroy the alert and redirects with a notice" do
        expect {
          delete destroy_subscription_path(other_alert, t: token)
        }.not_to change(Alert, :count)

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("could not be found")
      end
    end

    context "with a non-existent alert ID" do
      it "does not raise and redirects with a notice" do
        expect {
          delete destroy_subscription_path(id: SecureRandom.uuid, t: token)
        }.not_to raise_error

        expect(response).to redirect_to(manage_subscriptions_path(t: token))
        follow_redirect!
        expect(response.body).to include("could not be found")
      end
    end
  end

  describe "multiple alerts for the same email" do
    let(:token) { encode_manage_jwt(email) }
    let!(:alert_a) { create(:alert, :confirmed, :with_address, email: email, area: area, street_address: "100 N State St") }
    let!(:alert_b) { create(:alert, :confirmed, :with_address, email: email, area: area, street_address: "200 W Madison St") }
    let!(:alert_c) { create(:alert, :unconfirmed, :with_address, email: email, area: area, street_address: "300 S Wacker Dr") }

    it "shows all alerts for the email on the manage page" do
      get manage_subscriptions_path, params: { t: token }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("100 N State St")
      expect(response.body).to include("200 W Madison St")
      expect(response.body).to include("300 S Wacker Dr")
    end

    it "destroying one alert does not affect the others" do
      expect {
        delete destroy_subscription_path(alert_a, t: token)
      }.to change(Alert, :count).by(-1)

      expect(Alert.exists?(alert_b.id)).to be true
      expect(Alert.exists?(alert_c.id)).to be true
    end

    it "confirming one alert does not affect the others" do
      patch confirm_subscription_path(alert_c, t: token)

      expect(alert_c.reload.confirmed).to be true
      expect(alert_a.reload.confirmed).to be true
      expect(alert_b.reload.confirmed).to be true
    end

    it "updating permit_notifications on one alert does not affect the others" do
      patch update_subscription_path(alert_a, t: token), params: { permit_notifications: "0" }

      expect(alert_a.reload.permit_notifications).to be false
      expect(alert_b.reload.permit_notifications).to be true
    end

    it "does not allow actions on alerts belonging to a different email" do
      other_alert = create(:alert, :confirmed, :with_address, email: "other@example.com", area: area)

      delete destroy_subscription_path(other_alert, t: token)

      expect(Alert.exists?(other_alert.id)).to be true
    end
  end
end
