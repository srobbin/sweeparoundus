require "rails_helper"
require Rails.root.join("db/migrate/20260604000003_backfill_subscribers_for_alerts")

# Temporary coverage for the one-off Subscriber backfill (Deploy A / expand).
# Safe to delete once the contract migration (Deploy B) has shipped and these
# migrations are squashed away.
RSpec.describe BackfillSubscribersForAlerts do
  let!(:area) { create(:area) }

  before do
    # Start from a clean slate (factories/seeds may have left rows behind).
    # Alerts first to satisfy the subscriber FK.
    Alert.delete_all
    Subscriber.delete_all
  end

  # The real Alert hides `email` via ignored_columns, so write test rows through
  # the migration's own throwaway model, which can see the column.
  def create_raw_alert(**attrs)
    BackfillSubscribersForAlerts::MigrationAlert.create!(area_id: area.id, **attrs)
  end

  def raw_alerts
    BackfillSubscribersForAlerts::MigrationAlert
  end

  def migrate(direction)
    original = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    described_class.new.public_send(direction)
  ensure
    ActiveRecord::Migration.verbose = original
  end

  describe "#up" do
    it "creates one subscriber per distinct normalized email" do
      create_raw_alert(email: "User@Example.com", street_address: "123 Main St")
      create_raw_alert(email: "user@example.com", street_address: "456 Oak Ave")
      create_raw_alert(email: "other@example.com", street_address: "789 Pine Rd")

      expect { migrate(:up) }.to change(Subscriber, :count).from(0).to(2)
      expect(Subscriber.pluck(:email)).to contain_exactly("user@example.com", "other@example.com")
    end

    it "links every alert to its subscriber by normalized email" do
      create_raw_alert(email: "User@Example.com", street_address: "123 Main St")
      create_raw_alert(email: "user@example.com", street_address: "456 Oak Ave")

      migrate(:up)

      subscriber = Subscriber.find_by(email: "user@example.com")
      expect(Alert.where(subscriber_id: subscriber.id).count).to eq(2)
      expect(Alert.where(subscriber_id: nil)).to be_empty
    end

    it "deletes phone-only (NULL email) alerts before backfilling" do
      kept = create_raw_alert(email: "keep@example.com", street_address: "123 Main St")
      orphan = create_raw_alert(email: nil, street_address: "999 Phone Only")

      migrate(:up)

      expect(raw_alerts.exists?(kept.id)).to be true
      expect(raw_alerts.exists?(orphan.id)).to be false
    end

    it "stamps the subscriber with its earliest alert's created_at" do
      earliest = 3.days.ago.change(usec: 0)
      oldest = create_raw_alert(email: "user@example.com", street_address: "123 Main St")
      oldest.update_column(:created_at, earliest)
      create_raw_alert(email: "user@example.com", street_address: "456 Oak Ave")

      migrate(:up)

      expect(Subscriber.find_by(email: "user@example.com").created_at).to be_within(1.second).of(earliest)
    end

    it "raises on an address-level normalized-email collision and creates no subscribers" do
      create_raw_alert(email: "Dupe@example.com", street_address: "123 Main St")
      create_raw_alert(email: "dupe@example.com", street_address: "123 Main St")

      expect { migrate(:up) }.to raise_error(/collision/)
      expect(Subscriber.count).to eq(0)
    end

    it "raises on an area-wide normalized-email collision (NULL street address)" do
      create_raw_alert(email: "Dupe@example.com", street_address: nil)
      create_raw_alert(email: "dupe@example.com", street_address: nil)

      expect { migrate(:up) }.to raise_error(/collision/)
    end
  end

  describe "#down" do
    it "unlinks alerts and removes all subscribers" do
      create_raw_alert(email: "user@example.com", street_address: "123 Main St")
      migrate(:up)
      expect(Subscriber.count).to eq(1)

      migrate(:down)

      expect(Subscriber.count).to eq(0)
      expect(raw_alerts.where.not(subscriber_id: nil)).to be_empty
    end
  end
end
