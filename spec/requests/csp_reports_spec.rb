require "rails_helper"

RSpec.describe "CSP reports", type: :request do
  describe "POST /csp-violation-report" do
    def post_report(csp_report)
      post "/csp-violation-report",
           params: { "csp-report" => csp_report }.to_json,
           headers: { "CONTENT_TYPE" => "application/json" }
    end

    it "returns 204 No Content" do
      post_report("blocked-uri" => "https://example.com")

      expect(response).to have_http_status(:no_content)
    end

    it "logs genuine violations" do
      expect(Rails.logger).to receive(:warn).with(/\[CSP\]/)

      post_report(
        "violated-directive" => "script-src",
        "blocked-uri" => "https://evil.example.com/x.js"
      )
    end

    it "suppresses violations injected by browser extensions via source-file" do
      expect(Rails.logger).not_to receive(:warn)

      post_report(
        "violated-directive" => "script-src",
        "source-file" => "chrome-extension://abcdef/inject.js",
        "blocked-uri" => "inline"
      )
    end

    it "suppresses the Ibotta extension's authenticate.ibotta.com iframe" do
      expect(Rails.logger).not_to receive(:warn)

      post_report(
        "violated-directive" => "frame-src",
        "blocked-uri" => "https://authenticate.ibotta.com"
      )
    end

    it "does not crash on malformed JSON" do
      post "/csp-violation-report",
           params: "not json",
           headers: { "CONTENT_TYPE" => "application/json" }

      expect(response).to have_http_status(:no_content)
    end
  end
end
