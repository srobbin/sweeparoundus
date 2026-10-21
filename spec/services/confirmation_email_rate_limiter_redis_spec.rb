require "rails_helper"
require "securerandom"

RSpec.describe "Confirmation email limits with Redis", type: :service do
  let(:namespace) { "confirmation-limit-spec-#{SecureRandom.hex(12)}" }
  let(:store) { ActiveSupport::Cache::RedisCacheStore.new(url: ENV.fetch("REDIS_URL"), namespace: namespace) }

  before do
    skip "Set REDIS_URL to run Redis integration specs" if ENV["REDIS_URL"].blank?
    allow(Rack::Attack.cache).to receive(:store).and_return(store)
  end

  after do
    # Only this example's keys are removed, even on a shared development Redis.
    store.delete_matched("*") if ENV["REDIS_URL"].present?
  end

  it "atomically reserves a single confirmation across concurrent clients" do
    threads = 10.times.map do
      Thread.new { ConfirmationEmailRateLimiter.new("person@example.com").allowed? }
    end
    expect(threads.map(&:value).count(true)).to eq(1)
  end

  it "expires both cooldown and hourly counters" do
    stub_const("ConfirmationEmailRateLimiter::COOLDOWN", 1.second)
    stub_const("ConfirmationEmailRateLimiter::PERIOD", 1.second)
    stub_const("ConfirmationEmailRateLimiter::LIMIT", 1)

    expect(ConfirmationEmailRateLimiter.new("person@example.com").allowed?).to be true
    expect(ConfirmationEmailRateLimiter.new("person@example.com").allowed?).to be false
    # Redis expiry uses wall time, not Rails' travel helpers.
    sleep 1.1
    expect(ConfirmationEmailRateLimiter.new("person@example.com").allowed?).to be true
  end
end
