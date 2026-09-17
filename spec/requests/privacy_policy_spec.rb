require "rails_helper"

RSpec.describe "Privacy policy", type: :request do
  it "discloses Cloudflare Turnstile processing" do
    get privacy_policy_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Cloudflare Turnstile")
    expect(response.body).to include("https://www.cloudflare.com/privacypolicy/")
  end
end
