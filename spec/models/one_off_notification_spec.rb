require "rails_helper"

RSpec.describe OneOffNotification, type: :model do
  let(:alert) { create(:alert) }
  let(:attributes) { { alert: alert, campaign: "extended_season_2026", queued_at: Time.current } }

  it "requires an alert, campaign, and enqueue timestamp" do
    notification = described_class.new

    expect(notification).not_to be_valid
    expect(notification.errors).to include(:alert, :campaign, :queued_at)
  end

  it "allows the same alert to receive different one-off campaigns" do
    described_class.create!(attributes)

    expect { described_class.create!(attributes.merge(campaign: "another_campaign")) }
      .to change(described_class, :count).by(1)
  end

  it "enforces one receipt per campaign and alert in the database" do
    described_class.create!(attributes)

    expect do
      described_class.transaction(requires_new: true) { described_class.create!(attributes) }
    end.to raise_error(ActiveRecord::RecordNotUnique)
  end

  it "removes receipts when their alert is deleted" do
    described_class.create!(attributes)

    expect { alert.destroy! }.to change(described_class, :count).from(1).to(0)
  end
end
