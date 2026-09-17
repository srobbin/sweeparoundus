require "rails_helper"

RSpec.describe ManageLinkRateLimiter, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  before { Rack::Attack.cache.store.clear }
  after { Rack::Attack.cache.store.clear }

  it "allows requests through the configured limit" do
    described_class::LIMIT.times do
      expect(described_class.new("person@example.com").allowed?).to be true
    end
  end

  it "rejects requests over the configured limit" do
    described_class::LIMIT.times do
      described_class.new("person@example.com").allowed?
    end

    expect(described_class.new("person@example.com").allowed?).to be false
  end

  it "tracks different emails independently" do
    described_class::LIMIT.times do
      described_class.new("first@example.com").allowed?
    end

    expect(described_class.new("second@example.com").allowed?).to be true
  end

  it "allows requests again after the period expires" do
    freeze_time do
      described_class::LIMIT.times do
        described_class.new("person@example.com").allowed?
      end

      travel described_class::PERIOD + 1.second

      expect(described_class.new("person@example.com").allowed?).to be true
    end
  end
end
