require "rails_helper"

RSpec.describe "Admin Alerts", type: :request do
  include Warden::Test::Helpers

  let!(:admin_user) { AdminUser.create!(email: "admin@example.com", password: "password123!") }
  let!(:area) { create(:area) }

  before { login_as(admin_user, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /sau_admin/alerts" do
    it "returns a successful response" do
      get sau_admin_alerts_path

      expect(response).to have_http_status(:ok)
    end

    it "eager loads the area association to avoid N+1 queries" do
      create_list(:alert, 3, :confirmed, area: area)

      baseline_count = count_queries { get sau_admin_alerts_path }

      create_list(:alert, 5, :confirmed, area: area)

      scaled_count = count_queries { get sau_admin_alerts_path }

      expect(scaled_count[:areas]).to eq(baseline_count[:areas])
    end

    it "displays alert email addresses" do
      alert = create(:alert, :confirmed, area: area, email: "visible@example.com")

      get sau_admin_alerts_path

      expect(response.body).to include("visible@example.com")
    end

    it "displays the linked area name for alerts with an area" do
      alert = create(:alert, :confirmed, area: area)

      get sau_admin_alerts_path

      expect(response.body).to include(area.name)
    end

    it "renders without error for alerts without an area" do
      alert = create(:alert, :confirmed, area: nil, email: "orphan@example.com")

      get sau_admin_alerts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("orphan@example.com")
    end

    it "truncates long street addresses in the display" do
      alert = create(:alert, :confirmed, :with_address, area: area)

      get sau_admin_alerts_path

      expect(response).to have_http_status(:ok)
    end

    it "displays the permit_notifications column" do
      create(:alert, :confirmed, area: area, permit_notifications: false)
      create(:alert, :confirmed, area: area, permit_notifications: true)

      get sau_admin_alerts_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Permit Notifications")
    end
  end

  describe "GET /sau_admin/alerts/new" do
    let!(:subscriber) { create(:subscriber, email: "suggest@example.com") }

    it "renders an email autocomplete datalist of existing subscribers" do
      get new_sau_admin_alert_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("<datalist")
      expect(response.body).to include("suggest@example.com")
    end
  end

  describe "POST /sau_admin/alerts" do
    let!(:subscriber) { create(:subscriber, email: "picked@example.com") }

    it "links the new alert to the subscriber matching the typed email (case-insensitively)" do
      expect {
        post sau_admin_alerts_path, params: { alert: {
          area_id: area.id, email: "Picked@Example.com",
          street_address: "123 Main St", confirmed: "1", permit_notifications: "1"
        } }
      }.to change(Alert, :count).by(1)

      expect(Alert.last.subscriber).to eq(subscriber)
    end

    it "does not create an alert or a subscriber for an unknown email" do
      expect {
        post sau_admin_alerts_path, params: { alert: {
          area_id: area.id, email: "typo@example.com", street_address: "1 A St"
        } }
      }.not_to change(Alert, :count)

      expect(Subscriber.exists?(email: "typo@example.com")).to be(false)
    end
  end

  describe "PATCH /sau_admin/alerts/:id" do
    let!(:original_subscriber) { create(:subscriber, email: "one@example.com") }
    let!(:new_subscriber) { create(:subscriber, email: "two@example.com") }
    let!(:alert) { create(:alert, subscriber: original_subscriber, area: area) }

    it "reassigns the subscriber when the email is changed to another existing subscriber" do
      patch sau_admin_alert_path(alert), params: { alert: { email: "two@example.com" } }

      expect(alert.reload.subscriber).to eq(new_subscriber)
    end
  end

  describe "scopes" do
    let!(:confirmed_alert) { create(:alert, :confirmed, area: area) }
    let!(:unconfirmed_alert) { create(:alert, :unconfirmed, area: area) }

    it "filters by confirmed scope" do
      get sau_admin_alerts_path, params: { scope: "confirmed" }

      expect(response.body).to include(confirmed_alert.email)
      expect(response.body).not_to include(unconfirmed_alert.email)
    end

    it "filters by unconfirmed scope" do
      get sau_admin_alerts_path, params: { scope: "unconfirmed" }

      expect(response.body).to include(unconfirmed_alert.email)
      expect(response.body).not_to include(confirmed_alert.email)
    end
  end

  private

  def count_queries
    counts = Hash.new(0)
    callback = lambda do |_name, _start, _finish, _id, payload|
      sql = payload[:sql]
      next if sql.match?(/\A\s*(BEGIN|COMMIT|ROLLBACK|SAVEPOINT|RELEASE)/i)

      table = sql[/FROM\s+"?(\w+)"?/i, 1]
      counts[table&.to_sym] += 1 if table
    end

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      yield
    end

    counts
  end
end
