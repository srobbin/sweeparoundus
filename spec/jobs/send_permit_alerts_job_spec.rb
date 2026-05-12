# frozen_string_literal: true

require "rails_helper"

RSpec.describe SendPermitAlertsJob do
  include ActiveSupport::Testing::TimeHelpers

  # Pick a fixed instant in Chicago. The job uses Chicago day boundaries, so
  # midday Chicago time means there is no DST/UTC ambiguity in the day math.
  let(:chicago_now) { Time.use_zone("America/Chicago") { Time.zone.local(2026, 5, 7, 12, 0, 0) } }
  let(:chicago_today_start) { chicago_now.beginning_of_day }
  let(:chicago_tomorrow_start) { chicago_today_start + 1.day }

  let(:area) { create(:area) }

  before do
    allow(Rails.logger).to receive(:info)
    travel_to chicago_now
  end

  after { travel_back }

  # Helper to build a permit with explicit created_at so tests don't depend on
  # the system clock at the moment the row is inserted.
  def create_permit(unique_key:, application_start_date:, created_at: chicago_now, **rest)
    permit = create(:cdot_permit, unique_key: unique_key,
                    application_start_date: application_start_date, **rest)
    permit.update_columns(created_at: created_at)
    permit
  end

  describe "#perform" do
    context "permit scoping" do
      let!(:permit_starting_tomorrow) do
        create_permit(unique_key: "1000001",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end
      let!(:permit_starting_today_created_today) do
        create_permit(unique_key: "1000002",
                      application_start_date: chicago_today_start + 15.hours)
      end
      let!(:permit_starting_today_created_yesterday) do
        create_permit(unique_key: "1000003",
                      application_start_date: chicago_today_start + 15.hours,
                      created_at: chicago_today_start - 6.hours)
      end
      let!(:permit_starting_day_after_tomorrow) do
        create_permit(unique_key: "1000004",
                      application_start_date: chicago_tomorrow_start + 1.day + 9.hours)
      end
      let!(:permit_starting_in_the_past) do
        create_permit(unique_key: "1000005",
                      application_start_date: chicago_today_start - 2.days,
                      created_at: chicago_today_start - 2.days)
      end
      let!(:permit_closed_starting_tomorrow) do
        create_permit(unique_key: "1000006",
                      application_status: "Closed",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end

      before do
        # Stub the service so we can observe which permits it gets called with.
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |**_|
          instance_double(FindCdotPermitAffectedAlerts,
                          call: [], line_from: nil, line_to: nil,
                          pre_filter_skipped?: false)
        end
      end

      it "passes only permits starting tomorrow or starting-and-created today" do
        described_class.new.perform

        expected_keys = %w[1000001 1000002]
        expected_keys.each do |key|
          expect(FindCdotPermitAffectedAlerts).to have_received(:new)
            .with(permit: have_attributes(unique_key: key))
        end

        excluded_keys = %w[1000003 1000004 1000005]
        excluded_keys.each do |key|
          expect(FindCdotPermitAffectedAlerts).not_to have_received(:new)
            .with(permit: have_attributes(unique_key: key))
        end
      end

      it "skips permits whose status is no longer Open" do
        described_class.new.perform

        expect(FindCdotPermitAffectedAlerts).not_to have_received(:new)
          .with(permit: have_attributes(unique_key: "1000006"))
      end
    end

    context "delivering emails" do
      let!(:permit) do
        create_permit(unique_key: "2000001",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end

      let(:line_from) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }
      let(:line_to)   { GeocodeAddress::Result.new(lat: 41.94284, lng: -87.69870) }

      let(:eligible_alert) do
        build_stubbed(:alert, :confirmed, area: area, email: "ok@example.com",
                      street_address: "123 Main", lat: 41.942, lng: -87.6987,
                      permit_notifications: true)
      end
      # Phone-only subscriber: the proximity query in
      # FindCdotPermitAffectedAlerts doesn't filter on email (phone-only
      # alerts are valid for other channels), so the job has to skip these
      # explicitly. Confirmed + opted-in cases are already filtered in SQL
      # by the service and are covered by find_cdot_permit_affected_alerts_spec.
      let(:phone_only_alert) do
        build_stubbed(:alert, :confirmed, area: area, email: nil, phone: "+15551234567",
                      street_address: "789 Main", lat: 41.942, lng: -87.6987,
                      permit_notifications: true)
      end

      before do
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |**_|
          instance_double(
            FindCdotPermitAffectedAlerts,
            call: [
              FindCdotPermitAffectedAlerts::AffectedAlert.new(alert: eligible_alert, distance_feet: 100),
              FindCdotPermitAffectedAlerts::AffectedAlert.new(alert: phone_only_alert, distance_feet: 100),
            ],
            line_from: line_from,
            line_to: line_to,
            pre_filter_skipped?: false,
          )
        end
      end

      it "enqueues a PermitMailer.notify only for alerts with an email" do
        message = double("Mail").as_null_object
        allow(PermitMailer).to receive_message_chain(:with, :notify).and_return(message)

        described_class.new.perform

        expect(PermitMailer).to have_received(:with).once.with(
          hash_including(
            alert: eligible_alert,
            matches: [hash_including(
              permit: permit,
              distance_feet: 100,
              line_from: line_from,
              line_to: line_to,
            )],
          )
        )
      end

      it "stamps the permit with the notified alert ID and a timestamp" do
        allow(PermitMailer).to receive_message_chain(:with, :notify, :deliver_later)

        freeze_time do
          described_class.new.perform

          permit.reload
          expect(permit.processed_alert_ids).to eq([eligible_alert.id])
          expect(permit.notifications_sent_at).to eq(Time.current)
        end
      end

      it "logs per-permit and SUCCESS lines reflecting the filtered totals" do
        allow(PermitMailer).to receive_message_chain(:with, :notify, :deliver_later)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info)
          .with(/permit=2000001 segment="3300-3350 N CALIFORNIA AVE" matched=2 notified=1/)
        expect(Rails.logger).to have_received(:info).with(
          /SUCCESS: scanned 1 permit\(s\), 0 pre-filtered, 1 had notifiable alerts, 1 email\(s\) enqueued/
        )
      end

      # The other delivery tests stub `PermitMailer.with(...).notify` so the
      # ActiveJob serializer never runs against the real args. This test
      # deliberately leaves PermitMailer unstubbed so a regression in how
      # GeocodeAddress::Result is serialized (e.g. losing its custom
      # ObjectSerializer registration) would surface as a real
      # ActiveJob::SerializationError instead of passing silently.
      it "enqueues PermitMailer args that survive ActiveJob serialization" do
        # Persisted alert so ActionMailer's GlobalID serialization can
        # round-trip. (`build_stubbed` would suffice for enqueue-only, but
        # being explicit here keeps the test resilient if Rails ever runs
        # the deserialization path during enqueue.)
        persisted_alert = create(:alert, :confirmed, :with_address, area: area,
                                 email: "ok@example.com", lat: 41.942, lng: -87.6987,
                                 permit_notifications: true)
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |**_|
          instance_double(
            FindCdotPermitAffectedAlerts,
            call: [FindCdotPermitAffectedAlerts::AffectedAlert.new(alert: persisted_alert, distance_feet: 100)],
            line_from: line_from,
            line_to: line_to,
            pre_filter_skipped?: false,
          )
        end

        expect { described_class.new.perform }.not_to raise_error
      end
    end

    context "when one alert is affected by multiple permits" do
      let!(:permit_a) do
        create_permit(unique_key: "6000001",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end
      let!(:permit_b) do
        create_permit(unique_key: "6000002",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end

      let(:line_from) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }
      let(:line_to)   { GeocodeAddress::Result.new(lat: 41.94284, lng: -87.69870) }

      let(:eligible_alert) do
        build_stubbed(:alert, :confirmed, area: area, email: "ok@example.com",
                      street_address: "123 Main", lat: 41.942, lng: -87.6987,
                      permit_notifications: true)
      end

      before do
        # Each permit pretends to match the same alert, so the job has to
        # consolidate them into a single email instead of sending one per
        # permit.
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |permit:|
          instance_double(
            FindCdotPermitAffectedAlerts,
            call: [
              FindCdotPermitAffectedAlerts::AffectedAlert.new(
                alert: eligible_alert,
                distance_feet: permit == permit_a ? 100 : 200,
              ),
            ],
            line_from: line_from,
            line_to: line_to,
            pre_filter_skipped?: false,
          )
        end
      end

      it "stamps each permit with the notified alert ID" do
        allow(PermitMailer).to receive_message_chain(:with, :notify, :deliver_later)

        described_class.new.perform

        expect(permit_a.reload.processed_alert_ids).to eq([eligible_alert.id])
        expect(permit_b.reload.processed_alert_ids).to eq([eligible_alert.id])
      end

      it "sends a single email with both permits in the matches list" do
        message = double("Mail").as_null_object
        allow(PermitMailer).to receive_message_chain(:with, :notify).and_return(message)

        described_class.new.perform

        expect(PermitMailer).to have_received(:with).once
        expect(PermitMailer).to have_received(:with).with(
          hash_including(
            alert: eligible_alert,
            matches: a_collection_containing_exactly(
              hash_including(permit: permit_a, distance_feet: 100),
              hash_including(permit: permit_b, distance_feet: 200),
            ),
          )
        )
      end

      it "reports only one email enqueued in the SUCCESS summary" do
        allow(PermitMailer).to receive_message_chain(:with, :notify, :deliver_later)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(
          /SUCCESS: scanned 2 permit\(s\), 0 pre-filtered, 2 had notifiable alerts, 1 email\(s\) enqueued/
        )
      end
    end

    context "when no affected alerts are notifiable" do
      let!(:permit) do
        create_permit(unique_key: "3000001",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end
      let(:email_blank_alert) do
        build_stubbed(:alert, :confirmed, area: area, email: nil, phone: "+15551234567",
                      permit_notifications: true)
      end

      before do
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |**_|
          instance_double(
            FindCdotPermitAffectedAlerts,
            call: [
              FindCdotPermitAffectedAlerts::AffectedAlert.new(alert: email_blank_alert, distance_feet: 100),
            ],
            line_from: GeocodeAddress::Result.new(lat: 1, lng: 2),
            line_to: GeocodeAddress::Result.new(lat: 1, lng: 2),
            pre_filter_skipped?: false,
          )
        end
      end

      it "enqueues no emails and reports zero notified" do
        expect(PermitMailer).not_to receive(:with)

        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(
          /SUCCESS: scanned 1 permit\(s\), 0 pre-filtered, 0 had notifiable alerts, 0 email\(s\) enqueued/
        )
      end

      it "stamps the permit with an empty processed_alert_ids and a timestamp" do
        allow(PermitMailer).to receive(:with) # safety no-op

        described_class.new.perform

        expect(permit.reload.processed_alert_ids).to eq([])
        expect(permit.notifications_sent_at).to be_present
      end
    end

    context "when permits are pre-filtered" do
      let!(:permit_a) do
        create_permit(unique_key: "4000001",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end
      let!(:permit_b) do
        create_permit(unique_key: "4000002",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end

      before do
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |**_|
          instance_double(FindCdotPermitAffectedAlerts,
                          call: [], line_from: nil, line_to: nil,
                          pre_filter_skipped?: true)
        end
      end

      it "counts skipped permits in the SUCCESS summary" do
        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(
          /SUCCESS: scanned 2 permit\(s\), 2 pre-filtered, 0 had notifiable alerts, 0 email\(s\) enqueued/
        )
      end

      it "stamps pre-filtered permits with an empty processed_alert_ids and a timestamp" do
        described_class.new.perform

        [permit_a, permit_b].each do |p|
          p.reload
          expect(p.processed_alert_ids).to eq([])
          expect(p.notifications_sent_at).to be_present
        end
      end
    end

    context "when there are no permits in scope" do
      it "still logs the SUCCESS summary with zeros" do
        described_class.new.perform

        expect(Rails.logger).to have_received(:info).with(
          /SUCCESS: scanned 0 permit\(s\), 0 pre-filtered, 0 had notifiable alerts, 0 email\(s\) enqueued/
        )
      end
    end

    context "idempotency" do
      let!(:permit) do
        create_permit(unique_key: "7000001",
                      application_start_date: chicago_tomorrow_start + 9.hours)
      end

      let(:eligible_alert) do
        build_stubbed(:alert, :confirmed, area: area, email: "ok@example.com",
                      street_address: "123 Main", lat: 41.942, lng: -87.6987,
                      permit_notifications: true)
      end

      let(:line_from) { GeocodeAddress::Result.new(lat: 41.94142, lng: -87.69870) }
      let(:line_to)   { GeocodeAddress::Result.new(lat: 41.94284, lng: -87.69870) }

      before do
        allow(FindCdotPermitAffectedAlerts).to receive(:new) do |**_|
          instance_double(
            FindCdotPermitAffectedAlerts,
            call: [
              FindCdotPermitAffectedAlerts::AffectedAlert.new(alert: eligible_alert, distance_feet: 100),
            ],
            line_from: line_from,
            line_to: line_to,
            pre_filter_skipped?: false,
          )
        end
        allow(PermitMailer).to receive_message_chain(:with, :notify, :deliver_later)
      end

      it "skips already-notified permits on a second run" do
        described_class.new.perform
        expect(permit.reload.notifications_sent_at).to be_present

        RSpec::Mocks.space.proxy_for(PermitMailer).reset
        allow(PermitMailer).to receive_message_chain(:with, :notify, :deliver_later)

        described_class.new.perform

        expect(PermitMailer).not_to have_received(:with)
        expect(Rails.logger).to have_received(:info).with(
          /SUCCESS: scanned 0 permit\(s\), 0 pre-filtered, 0 had notifiable alerts, 0 email\(s\) enqueued/
        )
      end
    end
  end
end
