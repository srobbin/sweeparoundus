require "rails_helper"

RSpec.describe "security logging" do
  it "filters the exact manage-token parameter without filtering unrelated names" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    filtered = filter.filter(
      "t" => "manage-secret",
      "cf-turnstile-response" => "challenge-token",
      "lat" => "41.88"
    )

    expect(filtered["t"]).to eq("[FILTERED]")
    expect(filtered["cf-turnstile-response"]).to eq("[FILTERED]")
    expect(filtered["lat"]).to eq("41.88")
  end

  it "redacts the manage token from Rails request paths" do
    env = Rack::MockRequest.env_for("/subscriptions/manage?t=manage-secret&lat=41.88")
    env["action_dispatch.parameter_filter"] = Rails.application.config.filter_parameters
    request = ActionDispatch::Request.new(env)

    expect(request.filtered_path).to eq("/subscriptions/manage?t=[FILTERED]&lat=41.88")
  end

  it "drops a Sentry log if an unredacted manage token reaches the SDK" do
    log = Sentry::LogEvent.new(
      level: :info,
      body: 'Started GET "/subscriptions/manage?t=manage-secret"',
      attributes: {},
      origin: "auto.log.ruby.std_logger"
    )

    expect(Sentry.configuration.before_send_log.call(log)).to be_nil
  end

  it "keeps an already-redacted request log" do
    log = Sentry::LogEvent.new(
      level: :info,
      body: 'Started GET "/subscriptions/manage?t=[FILTERED]"',
      attributes: {},
      origin: "auto.log.ruby.std_logger"
    )

    expect(Sentry.configuration.before_send_log.call(log)).to be(log)
  end
end
