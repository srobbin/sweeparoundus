require "rails_helper"

RSpec.describe ConfirmationEmailRateLimiter, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  before { Rack::Attack.cache.store.clear }
  after { Rack::Attack.cache.store.clear }

  it "shares a cooldown across normalized email addresses" do
    expect(described_class.new(" Test@Example.com ").allowed?).to be true
    expect(described_class.new("test@example.com").allowed?).to be false
    expect(described_class.new("other@example.com").allowed?).to be true
  end

  it "allows another confirmation after the cooldown" do
    freeze_time do
      expect(described_class.new("test@example.com").allowed?).to be true
      travel described_class::COOLDOWN + 1.second
      expect(described_class.new("test@example.com").allowed?).to be true
    end
  end

  it "enforces the hourly limit and recovers after expiry" do
    freeze_time do
      described_class::LIMIT.times do
        expect(described_class.new("test@example.com").allowed?).to be true
        travel described_class::COOLDOWN + 1.second
      end
      expect(described_class.new("test@example.com").allowed?).to be false
      travel described_class::PERIOD + 1.second
      expect(described_class.new("test@example.com").allowed?).to be true
    end
  end

  it "fails closed when the cache cannot reserve a counter" do
    allow(Rack::Attack.cache.store).to receive(:increment).and_return(nil)
    limiter = described_class.new("test@example.com")
    expect(limiter.allowed?).to be false
    expect(limiter.unavailable?).to be true
  end

  it "distinguishes an hourly counter failure from exhausted quota" do
    allow(Rack::Attack.cache.store).to receive(:increment).and_return(1, nil)
    limiter = described_class.new("test@example.com")
    expect(limiter.allowed?).to be false
    expect(limiter.unavailable?).to be true
    expect(limiter.retry_after).to eq(60)
  end

  it "does not report a cooldown as a cache outage" do
    limiter = described_class.new("test@example.com")
    expect(limiter.allowed?).to be true
    expect(limiter.allowed?).to be false
    expect(limiter.unavailable?).to be false
  end

  it "does not extend the cooldown when a request is rejected" do
    freeze_time do
      expect(described_class.new("test@example.com").allowed?).to be true
      travel 30.seconds
      expect(described_class.new("test@example.com").allowed?).to be false
      travel 31.seconds
      expect(described_class.new("test@example.com").allowed?).to be true
    end
  end

  it "fails closed and logs only the error class when Redis raises" do
    allow(Rack::Attack.cache.store).to receive(:increment).and_raise(Redis::BaseError, "private connection details")
    allow(Rails.logger).to receive(:warn)

    limiter = described_class.new("test@example.com")
    expect(limiter.allowed?).to be false
    expect(limiter.unavailable?).to be true
    expect(Rails.logger).to have_received(:warn).with("[ConfirmationEmailRateLimiter] Cache unavailable: Redis::BaseError")
  end

  it "hashes email addresses in cache keys" do
    expect(Rack::Attack.cache.store).to receive(:increment)
      .with("confirmation-email/cooldown/#{Digest::SHA256.hexdigest('test@example.com')}", 1, expires_in: described_class::COOLDOWN)
      .and_return(nil)
    expect(described_class.new("test@example.com").allowed?).to be false
  end
end
