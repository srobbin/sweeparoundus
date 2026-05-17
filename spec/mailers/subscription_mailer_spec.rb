# frozen_string_literal: true

require "rails_helper"

RSpec.describe SubscriptionMailer, type: :mailer do
  include JwtHelper

  describe "#manage_link" do
    let(:email) { "test@example.com" }
    let(:mail) do
      described_class
        .with(email: email)
        .manage_link
        .deliver_now
    end
    let(:html_body) do
      mail.body.parts.find { |p| p.content_type.match "text/html" }.body.raw_source
    end
    let(:text_body) do
      mail.body.parts.find { |p| p.content_type.match "text/plain" }.body.raw_source
    end

    it "has the right attributes" do
      expect(mail.from).to eq([ ENV["DEFAULT_EMAIL"] ])
      expect(mail.subject).to eq("Manage your #{ENV["SITE_NAME"]} subscriptions")
      expect(mail.to).to eq([ email ])
    end

    it "includes the manage link in the HTML body" do
      expect(html_body).to include("manage your subscriptions")
      expect(html_body).to include(manage_subscriptions_url)
      expect(html_body).to include("expire in 1 hour")
    end

    it "includes the manage link in the text body" do
      expect(text_body).to include("manage your subscriptions")
      expect(text_body).to include(manage_subscriptions_url)
      expect(text_body).to include("expire in 1 hour")
    end

    it "embeds a valid JWT that decodes back to the correct email" do
      token = html_body.match(/[?&]t=([^"&\s]+)/)[1]
      decoded = decode_manage_jwt(token)

      expect(decoded["sub"]).to eq(email)
      expect(decoded["purpose"]).to eq("manage")
    end
  end
end
