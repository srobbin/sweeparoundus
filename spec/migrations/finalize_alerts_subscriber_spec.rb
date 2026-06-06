# frozen_string_literal: true

require "rails_helper"
require Rails.root.join("db", "migrate", "20260605000001_finalize_alerts_subscriber")

# TEMPORARY coverage for the Deploy B contract migration. It exercises the
# destructive up path (drop email/phone, enforce subscriber_id NOT NULL) and the
# recoverable down path (re-add columns, reconstruct email from the owning
# subscriber, rebuild the old indexes). Safe to delete once Deploy B is shipped
# and verified in production.
#
# Transactional fixtures are OFF here: the migration uses CREATE/DROP INDEX
# CONCURRENTLY, which Postgres refuses to run inside a transaction. Each example
# mutates the real schema, so the around hook always restores the canonical
# (migrated-up) state and clears the tables afterwards.
RSpec.describe FinalizeAlertsSubscriber do
  self.use_transactional_tests = false

  let(:connection) { ActiveRecord::Base.connection }

  def run_migration(direction)
    was_verbose = ActiveRecord::Migration.verbose
    ActiveRecord::Migration.verbose = false
    Prosopite.pause
    described_class.new.migrate(direction)
  ensure
    Prosopite.resume
    ActiveRecord::Migration.verbose = was_verbose
    connection.schema_cache.clear!
    [ Alert, Subscriber ].each(&:reset_column_information)
  end

  def alerts_in_expanded_state?
    connection.column_exists?(:alerts, :email)
  end

  def alert_column_names
    connection.columns(:alerts).map(&:name)
  end

  def alert_index_names
    connection.indexes(:alerts).map(&:name)
  end

  def subscriber_id_nullable?
    connection.columns(:alerts).find { |c| c.name == "subscriber_id" }.null
  end

  def clean_tables
    Alert.delete_all
    Subscriber.delete_all
    Area.delete_all
  end

  around do |example|
    run_migration(:up) if alerts_in_expanded_state? # recover from a crashed example
    clean_tables
    example.run
  ensure
    clean_tables
    run_migration(:up) if alerts_in_expanded_state?
  end

  describe "#up" do
    it "drops email/phone, removes the email indexes, and makes subscriber_id NOT NULL" do
      run_migration(:down)
      expect(alert_column_names).to include("email", "phone")
      expect(alert_index_names).to include(
        "index_alerts_on_email",
        "index_alerts_on_subscription_uniqueness",
        "index_alerts_on_email_area_without_address"
      )

      run_migration(:up)

      expect(alert_column_names).not_to include("email", "phone")
      expect(alert_index_names).not_to include(
        "index_alerts_on_email",
        "index_alerts_on_subscription_uniqueness",
        "index_alerts_on_email_area_without_address"
      )
      expect(subscriber_id_nullable?).to be(false)
    end

    it "refuses to run while any alert has a NULL subscriber_id" do
      run_migration(:down)
      connection.execute(
        "INSERT INTO alerts (email, created_at, updated_at) VALUES ('orphan@example.com', now(), now())"
      )

      expect { run_migration(:up) }.to raise_error(/NULL subscriber_id/)

      # Guard runs before any DDL, so the columns are still present (no partial drop).
      expect(alert_column_names).to include("email", "phone")
    end
  end

  describe "#down" do
    it "re-adds the columns and reconstructs alerts.email from the owning subscriber" do
      alert = create(:alert, email: "Person@Example.com")
      subscriber_email = alert.subscriber.email
      expect(subscriber_email).to eq("person@example.com")

      run_migration(:down)

      row = connection.select_one(
        "SELECT email, phone FROM alerts WHERE id = #{connection.quote(alert.id)}"
      )
      expect(row["email"]).to eq("person@example.com")
      expect(row["phone"]).to be_nil
    end

    it "reconstructs email for every alert sharing a subscriber" do
      area = create(:area)
      first = create(:alert, :with_address, area: area, email: "shared@example.com")
      second = create(:alert, :with_address, area: area, email: "shared@example.com")
      expect(first.subscriber_id).to eq(second.subscriber_id)

      run_migration(:down)

      emails = connection.select_values(
        "SELECT email FROM alerts WHERE id IN (#{connection.quote(first.id)}, #{connection.quote(second.id)})"
      )
      expect(emails).to all(eq("shared@example.com"))
    end

    it "restores subscriber_id to nullable and rebuilds the email indexes" do
      run_migration(:down)

      expect(subscriber_id_nullable?).to be(true)
      expect(alert_index_names).to include(
        "index_alerts_on_email",
        "index_alerts_on_subscription_uniqueness",
        "index_alerts_on_email_area_without_address"
      )
    end
  end
end
