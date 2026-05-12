# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupStaleCdotPermits, type: :service do
  include ActiveSupport::Testing::TimeHelpers

  subject { described_class.new }

  describe "#call" do
    it "deletes permits that are BOTH expired AND stale-synced" do
      doomed = create(:cdot_permit, application_expire_date: 2.days.ago, data_synced_at: 20.days.ago)

      result = subject.call

      expect(result).to include("deleted 1 stale permit(s)")
      expect(CdotPermit.find_by(id: doomed.id)).to be_nil
    end

    it "retains permits that are expired but still being re-synced (city renewal in flight)" do
      permit = create(:cdot_permit, application_expire_date: 5.days.ago, data_synced_at: 1.hour.ago)

      subject.call

      expect(CdotPermit.find_by(id: permit.id)).to be_present
    end

    it "retains permits that are stale-synced but not yet expired" do
      permit = create(:cdot_permit, application_expire_date: 30.days.from_now, data_synced_at: 20.days.ago)

      subject.call

      expect(CdotPermit.find_by(id: permit.id)).to be_present
    end

    it "retains permits with nil application_expire_date regardless of sync staleness" do
      fresh = create(:cdot_permit, application_expire_date: nil, data_synced_at: 1.hour.ago)
      stale = create(:cdot_permit, application_expire_date: nil, data_synced_at: 20.days.ago)

      subject.call

      expect(CdotPermit.find_by(id: fresh.id)).to be_present
      expect(CdotPermit.find_by(id: stale.id)).to be_present
    end

    it "deletes expired permits whose data_synced_at is nil (never successfully synced)" do
      permit = create(:cdot_permit, application_expire_date: 2.days.ago, data_synced_at: nil)

      subject.call

      expect(CdotPermit.find_by(id: permit.id)).to be_nil
    end

    it "leaves permits with a recent or future expire date untouched" do
      recent = create(:cdot_permit, application_expire_date: 12.hours.ago, data_synced_at: 1.hour.ago)
      future = create(:cdot_permit, application_expire_date: 30.days.from_now, data_synced_at: 1.hour.ago)

      subject.call

      expect(CdotPermit.find_by(id: recent.id)).to be_present
      expect(CdotPermit.find_by(id: future.id)).to be_present
    end

    it "does not wipe the table during a sync outage (every permit stale-synced but not expired)" do
      permits = Array.new(3) do |i|
        create(:cdot_permit, unique_key: "OUTAGE-#{i}",
               application_expire_date: 30.days.from_now,
               data_synced_at: 20.days.ago)
      end

      subject.call

      permits.each do |permit|
        expect(CdotPermit.find_by(id: permit.id)).to be_present
      end
    end

    it "returns a success message with the count and cutoffs" do
      create(:cdot_permit, application_expire_date: 3.days.ago, data_synced_at: 20.days.ago)
      create(:cdot_permit, application_expire_date: 5.days.ago, data_synced_at: 21.days.ago)

      result = subject.call

      expect(result).to match(/SUCCESS: deleted 2 stale permit\(s\)/)
      expect(result).to include("AND not synced since")
    end

    it "returns zero count when nothing to delete" do
      result = subject.call

      expect(result).to include("deleted 0 stale permit(s)")
    end

    it "re-raises database errors after logging" do
      allow(CdotPermit).to receive(:where).and_raise(ActiveRecord::StatementInvalid.new("boom"))
      allow(Rails.logger).to receive(:error)

      expect { subject.call }.to raise_error(ActiveRecord::StatementInvalid)
      expect(Rails.logger).to have_received(:error).with(/boom/)
    end
  end
end
