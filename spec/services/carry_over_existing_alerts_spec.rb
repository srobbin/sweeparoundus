require 'rails_helper'

RSpec.describe CarryOverExistingAlerts, type: :service do
  subject { described_class.new(write: true).call}
  let!(:alert) { create(:alert, :confirmed, street_address: street_address) }
  let(:street_address) { '2741 N Central Park Ave, Chicago, IL 60647' }

  before do
    ActiveJob::Base.queue_adapter = :test
    allow_any_instance_of(CarryOverExistingAlerts).to receive(:sleep)
    stub_request(:get, /maps.googleapis.com/)
      .to_return(body: File.read(Rails.root.join('spec', 'fixtures', 'google_maps_response.json')))
    allow(Area).to receive(:where).and_return([alert.area])
  end

  context 'when alerts have valid addresses' do
    it 'returns a success message' do
      expect(subject).to eq('SUCCESS: All alerts have been assigned to an area')
    end

    it 'updates the alert with the correct area and coordinates' do
      subject
      alert.reload
      expect(alert.area).not_to be_nil
      expect(alert.lat).not_to be_nil
      expect(alert.lng).not_to be_nil
    end

    it 'sends an annual schedule live email' do
      expect { subject }.to have_enqueued_mail(AlertMailer, :annual_schedule_live).with(params: { alert: alert.reload }, args: [])
    end
  end

  context 'when alerts have invalid addresses' do
    let(:street_address) { 'invalid address' }

    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: File.read(Rails.root.join('spec', 'fixtures', 'google_maps_failure_response.json')))
    end

    it 'returns an error message' do
      expect(subject).to start_with('ERROR: Failed to find areas for')
    end

    it 'does not update the alert' do
      expect { subject }.not_to change { alert.reload.area }
    end

    it 'adds the alert to failures with geocode reason' do
      service = described_class.new(write: true)
      service.call
      expect(service.failures).to contain_exactly(
        a_hash_including(id: alert.id, reason: "geocode_status: ZERO_RESULTS")
      )
    end
  end

  context 'when there is a network error' do
    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_raise(StandardError.new('Network error'))
    end

    it 'retries the request' do
      expect_any_instance_of(CarryOverExistingAlerts).to receive(:sleep).at_least(:once)
      subject
    end

    it 'adds the alert to failures with http_error reason' do
      service = described_class.new(write: true)
      service.call
      expect(service.failures).to contain_exactly(
        a_hash_including(id: alert.id, reason: "http_error: Network error")
      )
    end
  end

  context 'when multiple alerts fail geocoding before a valid one' do
    let!(:invalid_alert_1) { create(:alert, :confirmed, street_address: 'invalid address 1', area: alert.area) }
    let!(:invalid_alert_2) { create(:alert, :confirmed, street_address: 'invalid address 2', area: alert.area) }

    before do
      failure_body = File.read(Rails.root.join('spec', 'fixtures', 'google_maps_failure_response.json'))

      stub_request(:get, /maps.googleapis.com.*invalid/)
        .to_return(body: failure_body)
    end

    it 'does not raise a TypeError from accumulated failure hashes' do
      expect { subject }.not_to raise_error
    end

    it 'records the failed alerts with reasons' do
      service = described_class.new(write: true)
      service.call
      expect(service.failures).to contain_exactly(
        a_hash_including(id: invalid_alert_1.id, reason: "geocode_status: ZERO_RESULTS"),
        a_hash_including(id: invalid_alert_2.id, reason: "geocode_status: ZERO_RESULTS")
      )
    end
  end

  context 'when write is false' do
    subject { described_class.new(write: false).call }

    it 'does not update the alert' do
      expect { subject }.not_to change { alert.reload.area }
    end

    it 'does not send an annual schedule live email' do
      expect { subject }.not_to have_enqueued_mail(AlertMailer, :annual_schedule_live)
    end
  end

  context 'when send_mailers is false' do
    subject { described_class.new(write: true, send_mailers: false).call }

    it 'still updates the alert with the correct area and coordinates' do
      subject
      alert.reload
      expect(alert.area).not_to be_nil
      expect(alert.lat).not_to be_nil
      expect(alert.lng).not_to be_nil
    end

    it 'does not send an annual schedule live email' do
      expect { subject }.not_to have_enqueued_mail(AlertMailer, :annual_schedule_live)
    end
  end

  context 'when alert update fails' do
    before do
      allow_any_instance_of(Alert).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(alert))
    end

    it 'adds the alert to failures with update_failed reason' do
      service = described_class.new(write: true)
      service.call
      expect(service.failures).to contain_exactly(
        a_hash_including(id: alert.id, reason: start_with("update_failed:"))
      )
    end

    it 'does not send an annual schedule live email' do
      expect { subject }.not_to have_enqueued_mail(AlertMailer, :annual_schedule_live)
    end
  end
end
