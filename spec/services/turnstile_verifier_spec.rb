require "rails_helper"

RSpec.describe TurnstileVerifier, type: :service do
  subject(:verify) do
    described_class.new(
      token: token,
      remote_ip: "203.0.113.10",
      expected_hostname: expected_hostname
    ).call
  end

  let(:token) { "response-token" }
  let(:expected_hostname) { "example.com" }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return("site-key")
    allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return("secret-key")
  end

  it "accepts a successful verification" do
    stub_request(:post, described_class::VERIFY_URL)
      .with(body: hash_including(
        "secret" => "secret-key",
        "response" => token,
        "remoteip" => "203.0.113.10"
      ))
      .to_return(body: {
        success: true,
        action: described_class::ACTION,
        hostname: expected_hostname
      }.to_json)

    expect(verify).to be true
  end

  it "rejects a failed verification" do
    stub_request(:post, described_class::VERIFY_URL)
      .to_return(body: { success: false, "error-codes": [ "invalid-input-response" ] }.to_json)

    expect(verify).to be false
  end

  it "rejects a token issued for a different action" do
    stub_request(:post, described_class::VERIFY_URL)
      .to_return(body: {
        success: true,
        action: "different-form",
        hostname: expected_hostname
      }.to_json)

    expect(verify).to be false
  end

  it "rejects a token issued for a different hostname" do
    stub_request(:post, described_class::VERIFY_URL)
      .to_return(body: {
        success: true,
        action: described_class::ACTION,
        hostname: "attacker.example"
      }.to_json)

    expect(verify).to be false
  end

  it "rejects a blank response without contacting Cloudflare" do
    verifier = described_class.new(
      token: "",
      remote_ip: "203.0.113.10",
      expected_hostname: expected_hostname
    )

    expect(verifier.call).to be false
    expect(WebMock).not_to have_requested(:post, described_class::VERIFY_URL)
  end

  it "rejects malformed responses without raising" do
    allow(Rails.logger).to receive(:warn)
    stub_request(:post, described_class::VERIFY_URL).to_return(body: "not-json")

    expect(verify).to be false
    expect(Rails.logger).to have_received(:warn).with(/JSON::ParserError/)
  end

  [ "null", "[]" ].each do |body|
    it "rejects the valid non-object JSON response #{body} without raising" do
      stub_request(:post, described_class::VERIFY_URL).to_return(body: body)

      expect(verify).to be false
    end
  end

  it "rejects a non-success HTTP response" do
    stub_request(:post, described_class::VERIFY_URL).to_return(status: 503)

    expect(verify).to be false
  end

  it "rejects network failures without raising" do
    allow(Rails.logger).to receive(:warn)
    stub_request(:post, described_class::VERIFY_URL).to_timeout

    expect(verify).to be false
    expect(Rails.logger).to have_received(:warn).with(/Verification unavailable/)
  end

  context "without configuration" do
    before do
      allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return(nil)
      allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return(nil)
    end

    it "is bypassed outside production for local development and tests" do
      expect(verify).to be true
      expect(WebMock).not_to have_requested(:post, described_class::VERIFY_URL)
    end

    it "fails closed in production" do
      allow(Rails.env).to receive(:production?).and_return(true)

      expect(verify).to be false
      expect(WebMock).not_to have_requested(:post, described_class::VERIFY_URL)
    end
  end
end
