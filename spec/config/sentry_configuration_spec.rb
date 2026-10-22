require "rails_helper"

RSpec.describe "Sentry configuration" do
  let(:config) { Sentry.configuration }
  let(:filter) { config.before_send_log }

  def log(body: "Request completed", attributes: {}, origin: "auto.log.rails.log_subscriber")
    Struct.new(:body, :attributes, :origin).new(body, attributes, origin)
  end

  it "keeps Rails structured logging and the logger patch enabled" do
    expect(config.rails.structured_logging.enabled).to be true
    expect(config.enabled_patches).to include(:logger)
  end

  it "restricts reporting to production and keeps default PII collection disabled" do
    expect(config.enabled_environments).to eq([ "production" ])
    expect(config.send_default_pii).to be false
  end

  it "drops raw management tokens in log messages and attributes" do
    expect(filter.call(log(body: "GET /subscriptions/manage?t=secret"))).to be_nil
    expect(filter.call(log(attributes: { path: "/subscriptions/manage?t=secret" }))).to be_nil
  end

  it "retains logs with redacted management tokens" do
    entry = log(body: "GET /subscriptions/manage?t=[FILTERED]", attributes: { status: 200 })
    expect(filter.call(entry)).to equal(entry)
  end

  it "drops expected Rails 404 and API validation logs" do
    expect(filter.call(log(attributes: { status: 404, path: "/missing" }))).to be_nil
    expect(filter.call(log(attributes: { "status" => 422, "path" => "/api/v1/sweeps" }))).to be_nil
  end

  it "retains non-API validation failures and application logs" do
    validation = log(attributes: { status: 422, path: "/subscriptions" })
    application = log(origin: "manual", attributes: { status: 404 })
    expect(filter.call(validation)).to equal(validation)
    expect(filter.call(application)).to equal(application)
  end
end
