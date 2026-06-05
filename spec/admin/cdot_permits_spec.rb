require "rails_helper"

RSpec.describe "Admin CdotPermits", type: :request do
  include Warden::Test::Helpers

  let!(:admin_user) { AdminUser.create!(email: "admin@example.com", password: "password123!") }

  before { login_as(admin_user, scope: :admin_user) }
  after { Warden.test_reset! }

  describe "GET /sau_admin/cdot_permits" do
    it "returns a successful response" do
      create(:cdot_permit)

      get sau_admin_cdot_permits_path

      expect(response).to have_http_status(:ok)
    end
  end

  describe "GET /sau_admin/cdot_permits/:id" do
    let!(:permit) { create(:cdot_permit) }

    # ActiveAdmin's Pundit adapter authorizes the `show` action via `show?`,
    # which defaults to false. Admin::CdotPermitPolicy must opt in explicitly or
    # this page returns AccessDenied — this guards that.
    it "renders the show page" do
      get sau_admin_cdot_permit_path(permit)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(permit.unique_key)
    end
  end
end
