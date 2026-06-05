require "rails_helper"

RSpec.describe "Admin Subscribers", type: :request do
  include Warden::Test::Helpers

  let!(:admin_user) { AdminUser.create!(email: "admin@example.com", password: "password123!") }
  let!(:area) { create(:area) }

  before { login_as(admin_user, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /sau_admin/subscribers" do
    it "returns a successful response and lists subscriber emails" do
      create(:subscriber, email: "listed@example.com")

      get sau_admin_subscribers_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("listed@example.com")
    end
  end

  describe "GET /sau_admin/subscribers/:id" do
    let!(:subscriber) { create(:subscriber, email: "shown@example.com") }

    # ActiveAdmin's Pundit adapter authorizes the `show` action via `show?`,
    # which defaults to false. Admin::SubscriberPolicy must opt in explicitly or
    # this page returns AccessDenied — this guards that.
    it "renders the show page with the subscriber and its alerts" do
      create(:alert, :confirmed, :with_address, subscriber: subscriber, area: area)

      get sau_admin_subscriber_path(subscriber)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("shown@example.com")
      expect(response.body).to include(area.name)
    end
  end

  describe "DELETE /sau_admin/subscribers/:id" do
    let!(:subscriber) { create(:subscriber, email: "deleted@example.com") }

    it "destroys the subscriber and its dependent alerts" do
      create(:alert, :confirmed, subscriber: subscriber, area: area)

      expect {
        delete sau_admin_subscriber_path(subscriber)
      }.to change(Subscriber, :count).by(-1).and change(Alert, :count).by(-1)
    end
  end
end
