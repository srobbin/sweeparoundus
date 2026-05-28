require "rails_helper"
require "active_support/cache/redis_cache_store"

# Regression guard for the Rails 7.2 + connection_pool interaction.
#
# Rails 7.2.x's RedisCacheStore calls `::ConnectionPool.new(pool_options)`
# with a positional hash. connection_pool 3.0 made `initialize` keyword-only,
# so that call raises `ArgumentError: wrong number of arguments (given 1, expected 0)`
# at construction time.
#
# The test env normally configures `Rails.cache` as `:null_store`, so a stock
# `Rails.cache` spec would silently dodge the regression. Build a real
# RedisCacheStore against the dev Redis to exercise the broken code path.
#
# When this app moves to Rails 8.x (which uses `ConnectionPool.new(**pool_options)`),
# the connection_pool pin in the Gemfile can be relaxed and this spec
# becomes a general "we can talk to Redis" smoke check.
RSpec.describe ActiveSupport::Cache::RedisCacheStore do
  subject(:store) do
    described_class.new(
      url: ENV.fetch("REDIS_URL"),
      db: 15,
      ssl_params: { verify_mode: OpenSSL::SSL::VERIFY_NONE }
    )
  end

  before { store.clear }
  after  { store.clear }

  it "instantiates without ArgumentError under the installed connection_pool" do
    expect { store }.not_to raise_error
  end

  it "performs basic read/write/increment against Redis" do
    aggregate_failures do
      store.write("k", "v")
      expect(store.read("k")).to eq("v")

      store.write("c", 0, raw: true)
      5.times { store.increment("c") }
      expect(store.read("c", raw: true).to_i).to eq(5)

      store.delete("k")
      expect(store.read("k")).to be_nil
    end
  end
end
