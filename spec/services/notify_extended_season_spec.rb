# frozen_string_literal: true

require "rails_helper"

RSpec.describe NotifyExtendedSeason, type: :service do
  describe "#call" do
    let!(:area) { create(:area, ward: 28) }
    let!(:alert_confirmed_with_address) { create(:alert, :confirmed, :with_address, area: area) }
    let!(:alert_confirmed_no_address) { create(:alert, :confirmed, area: area) }
    let!(:alert_unconfirmed) { create(:alert, :unconfirmed, :with_address, area: area) }
    let!(:alert_without_area) { create(:alert, :confirmed, :with_address, area: nil) }

    context "when write is false" do
      subject { described_class.new(write: false).call }

      it "does not send any emails" do
        expect(AlertMailer).not_to receive(:with)
        subject
      end

      it "returns test result string with count" do
        expect(subject).to eq("TEST: 2 confirmed alert(s) would be notified of extended season")
      end
    end

    context "when write is true" do
      subject { described_class.new(write: true).call }

      let(:alert_mailer_dbl) { double(AlertMailer) }

      before do
        allow(AlertMailer).to receive(:with).and_return(alert_mailer_dbl)
        allow(alert_mailer_dbl).to receive(:extended_season_notice).and_return(alert_mailer_dbl)
        allow(alert_mailer_dbl).to receive(:deliver_later).and_return(double("queued job"))
        allow(WardOfficeLookup).to receive(:new).and_return(
          instance_double(WardOfficeLookup, for_ward: { ward: "28", alderperson: "Test Person", phone: "123", email: "a@example.com", website: nil })
        )
      end

      it "sends mailers to confirmed alerts only" do
        subject
        expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_with_address, ward_office: hash_including(ward: "28"))
        expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_no_address, ward_office: hash_including(ward: "28"))
        expect(AlertMailer).not_to have_received(:with).with(alert: alert_unconfirmed, ward_office: anything)
        expect(AlertMailer).not_to have_received(:with).with(alert: alert_without_area, ward_office: anything)
      end

      it "calls extended_season_notice and deliver_later for each" do
        subject
        expect(alert_mailer_dbl).to have_received(:extended_season_notice).twice
        expect(alert_mailer_dbl).to have_received(:deliver_later).twice
      end

      it "returns success result string" do
        expect(subject).to eq("SUCCESS: 2 confirmed alert(s) notified of extended season")
      end

      it "records progress and skips previously queued alerts on reruns" do
        subject
        [ alert_confirmed_with_address, alert_confirmed_no_address ].each do |alert|
          receipt = OneOffNotification.find_by!(campaign: described_class::CAMPAIGN, alert: alert)
          expect(receipt.queued_at).to be_present
        end
        expect(described_class.new(write: false).call).to eq("TEST: 0 confirmed alert(s) would be notified of extended season")
        expect(described_class.new(write: true).call).to eq("SUCCESS: 0 confirmed alert(s) notified of extended season")
        expect(alert_mailer_dbl).to have_received(:deliver_later).twice
      end

      it "resumes after an enqueue failure without repeating the successful enqueue" do
        attempts = 0
        allow(alert_mailer_dbl).to receive(:deliver_later) do
          attempts += 1
          raise "Queue unavailable" if attempts == 2
          double("queued job")
        end

        expect { subject }.to raise_error("Queue unavailable")
        expect(OneOffNotification.where(campaign: described_class::CAMPAIGN).count).to eq(1)
        expect(described_class.new(write: true).call).to eq("SUCCESS: 1 confirmed alert(s) notified of extended season")
        expect(attempts).to eq(3)
      end

      it "does not mark alerts when enqueueing is aborted" do
        allow(alert_mailer_dbl).to receive(:deliver_later).and_return(false)

        expect { subject }.to raise_error(/enqueue failed/)
        expect(OneOffNotification.where(campaign: described_class::CAMPAIGN)).to be_empty
      end

      it "does not skip alerts notified by a different one-off campaign" do
        OneOffNotification.create!(campaign: "another_campaign", alert: alert_confirmed_with_address, queued_at: Time.current)

        expect(subject).to eq("SUCCESS: 2 confirmed alert(s) notified of extended season")
        expect(OneOffNotification.where(campaign: described_class::CAMPAIGN).count).to eq(2)
      end

      [ Errno::ENOENT, Errno::EACCES, CSV::MalformedCSVError ].each do |error_class|
        context "when ward office lookup raises #{error_class}" do
          before do
            error = if error_class == CSV::MalformedCSVError
              error_class.new("Invalid CSV", 1)
            else
              error_class.new("Ward office CSV")
            end
            lookup = instance_double(WardOfficeLookup)
            allow(lookup).to receive(:for_ward).and_raise(error)
            allow(WardOfficeLookup).to receive(:new).and_return(lookup)
            expect(lookup).to receive(:for_ward).once
          end

          it "continues notifying all confirmed alerts without ward office details" do
            expect(subject).to eq("SUCCESS: 2 confirmed alert(s) notified of extended season")
            expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_with_address, ward_office: nil)
            expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_no_address, ward_office: nil)
            expect(alert_mailer_dbl).to have_received(:deliver_later).twice
          end
        end
      end
    end

    context "when required ENV vars are missing" do
      subject { described_class.new(write: false).call }

      it "raises when SITE_NAME is blank" do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SITE_NAME").and_return(nil)

        expect { subject }.to raise_error(RuntimeError, /SITE_NAME and SITE_URL must be set/)
      end
    end
  end
end
