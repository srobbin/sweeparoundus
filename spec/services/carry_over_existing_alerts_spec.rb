require 'rails_helper'

RSpec.describe CarryOverExistingAlerts, type: :service do
  subject { described_class.new(write: true).call}
  let!(:alert) { create(:alert, :confirmed, street_address: street_address) }
  let(:street_address) { '2741 N Central Park Ave, Chicago, IL 60647' }

  before do
    ActiveJob::Base.queue_adapter = :test
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
      expect(alert.area).to eq(alert.area)
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

    it 'adds the alert to failures' do
      subject
      expect(subject).to include("ERROR: Failed to find areas for 1 alert(s):")
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

    it 'adds the alert to failures after max retries' do
      subject
      expect(subject).to include("ERROR: Failed to find areas for 1 alert(s):")
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

  context 'when alert update fails' do
    before do
      allow_any_instance_of(Alert).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(alert))
    end

    it 'adds the alert to failures' do
      subject
      expect(subject).to include("ERROR: Failed to find areas for 1 alert(s):")
    end

    it 'does not send an annual schedule live email' do
      expect { subject }.not_to have_enqueued_mail(AlertMailer, :annual_schedule_live)
    end
  end
end
