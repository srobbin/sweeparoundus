require "rails_helper"

RSpec.describe "Turnstile configuration" do
  let(:initializer) { Rails.root.join("config/initializers/turnstile.rb") }

  before do
    allow(Rails.env).to receive(:production?).and_return(true)
    allow(ENV).to receive(:[]).and_call_original
  end

  it "raises during production boot when either key is missing" do
    allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return("site-key")
    allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return(nil)

    expect { load initializer }.to raise_error(
      KeyError,
      "Missing required Turnstile configuration: TURNSTILE_SECRET_KEY"
    )
  end

  it "allows production boot when both keys are present" do
    allow(ENV).to receive(:[]).with("TURNSTILE_SITE_KEY").and_return("site-key")
    allow(ENV).to receive(:[]).with("TURNSTILE_SECRET_KEY").and_return("secret-key")

    expect { load initializer }.not_to raise_error
  end
end
