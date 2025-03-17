# frozen_string_literal: true

require 'rails_helper'

RSpec.describe DestroyIneligibleAlerts, type: :service do
  describe '.call' do
    let!(:area) { create(:area) }
    let!(:alert_confirmed_no_address) { create(:alert, :confirmed, area: area, created_at: 1.year.ago) }
    let!(:alert_confirmed_with_address) { create(:alert, :confirmed, :with_address, area: area, created_at: 1.year.ago) }
    let!(:alert_unconfirmed_no_address) { create(:alert, :unconfirmed, area: area, created_at: 1.year.ago) }
    let!(:alert_unconfirmed_with_address) { create(:alert, :unconfirmed, :with_address, area: area, created_at: 1.year.ago) }

    context 'when write is false' do
      subject { described_class.new(write: false).call }
      let(:expected_result) { "TEST: 3 alerts (unconfirmed or without street address) marked for deletion" }

      it 'does not destroy any alerts' do
        expect { subject }.not_to change { Alert.count }
        expect(Alert.exists?(alert_confirmed_no_address.id)).to be_truthy
        expect(Alert.exists?(alert_confirmed_with_address.id)).to be_truthy
        expect(Alert.exists?(alert_unconfirmed_no_address.id)).to be_truthy
        expect(Alert.exists?(alert_unconfirmed_with_address.id)).to be_truthy
      end

      it 'returns test result string' do
        result = subject
        expect(result).to eq(expected_result)
      end
    end

    context 'when write is true' do
      subject { described_class.new(write: true).call }
      let(:expected_result) { "SUCCESS: 3 alerts (unconfirmed or without street address) deleted" }
      let(:alert_mailer_dbl) { double(AlertMailer) }

      before do
        allow(AlertMailer).to receive(:with).and_return(alert_mailer_dbl)
        allow(alert_mailer_dbl).to receive(:deleted_notification).and_return(alert_mailer_dbl)
        allow(alert_mailer_dbl).to receive(:deliver_later)
      end

      it 'sends mailers to confirmed alerts to be deleted' do
        subject
        expect(AlertMailer).to have_received(:with).with(alert: alert_confirmed_no_address)
        expect(alert_mailer_dbl).to have_received(:deleted_notification)
        expect(alert_mailer_dbl).to have_received(:deliver_later)
      end

      it 'destroys all alerts that are unconfirmed or without street addresses' do
        expect { subject }.to change { Alert.count }.by(-3)
        expect(Alert.exists?(alert_confirmed_no_address.id)).to be_falsey
        expect(Alert.exists?(alert_confirmed_with_address.id)).to be_truthy
        expect(Alert.exists?(alert_unconfirmed_no_address.id)).to be_falsey
        expect(Alert.exists?(alert_unconfirmed_with_address.id)).to be_falsey
      end

      it 'returns success result string' do
        result = subject
        expect(result).to eq(expected_result)
      end
    end
  end
end