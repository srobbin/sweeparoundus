require 'rails_helper'

RSpec.describe CarryOverExistingAlerts, type: :service do
  subject { described_class.new(write: true).call}

  before do
    stub_request(:get, /maps.googleapis.com/)
      .to_return(body: File.read(Rails.root.join('spec', 'fixtures', 'google_maps_response.json')))
    allow(Area).to receive(:where).and_return([alert.area])
  end

  context 'when alerts have valid addresses' do
    let!(:alert) { create(:alert, :confirmed, street_address: '2741 N Central Park Ave, Chicago, IL 60647') }

    it 'returns a success message' do
      expect(subject).to eq('SUCCESS: All alerts have been assigned to an area')
    end
  end

  context 'when alerts have invalid addresses' do
    let!(:alert) { create(:alert, :confirmed, street_address: 'invalid address') }

    before do
      stub_request(:get, /maps.googleapis.com/)
        .to_return(body: File.read(Rails.root.join('spec', 'fixtures', 'google_maps_failure_response.json')))
    end

    it 'returns an error message' do
      expect(subject).to start_with('ERROR: Failed to find areas for')
    end
  end
end