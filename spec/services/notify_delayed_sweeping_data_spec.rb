# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotifyDelayedSweepingData, type: :service do
  describe '#call' do
    let!(:area) { create(:area) }
    let!(:alert_confirmed_with_address) { create(:alert, :confirmed, :with_address, area: area) }
    let!(:alert_confirmed_no_address) { create(:alert, :confirmed, area: area) }
    let!(:alert_unconfirmed) { create(:alert, :unconfirmed, :with_address, area: area) }

    context 'when write is false' do
      subject { described_class.new(write: false).call }

      it 'does not send any emails' do
        expect(AlertMailer).not_to receive(:with)
        subject
      end

      it 'returns test result string with count' do
        expect(subject).to eq("TEST: 2 confirmed alert(s) would be notified")
      end
    end

    context 'when write is true' do
      subject { described_class.new(write: true).call }

      let(:alert_mailer_dbl) { double(AlertMailer) }

      before do
        allow(AlertMailer).to receive(:with).and_return(alert_mailer_dbl)
        allow(alert_mailer_dbl).to receive(:sweeping_data_delayed).and_return(alert_mailer_dbl)
        allow(alert_mailer_dbl).to receive(:deliver_later)
      end

      it 'sends mailers to confirmed alerts only' do
        subject
        expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_with_address)
        expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_no_address)
        expect(AlertMailer).not_to have_received(:with).with(alert: alert_unconfirmed)
      end

      context 'with a phone-only confirmed alert' do
        let!(:phone_only_alert) { Alert.create!(phone: "3125551234", confirmed: true, area: area) }

        it 'excludes phone-only alerts (no email to send to)' do
          subject
          expect(AlertMailer).not_to have_received(:with).with(alert: phone_only_alert)
        end
      end

      it 'calls sweeping_data_delayed and deliver_later for each' do
        subject
        expect(alert_mailer_dbl).to have_received(:sweeping_data_delayed).twice
        expect(alert_mailer_dbl).to have_received(:deliver_later).twice
      end

      it 'returns success result string' do
        expect(subject).to eq("SUCCESS: 2 confirmed alert(s) notified")
      end
    end

    context 'when required ENV vars are missing' do
      subject { described_class.new(write: false).call }

      it 'raises when SITE_NAME is blank' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SITE_NAME").and_return(nil)

        expect { subject }.to raise_error(RuntimeError, /SITE_NAME and SITE_URL must be set/)
      end

      it 'raises when SITE_URL is blank' do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SITE_URL").and_return(nil)

        expect { subject }.to raise_error(RuntimeError, /SITE_NAME and SITE_URL must be set/)
      end
    end
  end
end
