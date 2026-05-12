# frozen_string_literal: true

require "rails_helper"

RSpec.describe SyncCdotPermitsJob do
  describe "#perform" do
    it "delegates to SyncCdotPermits and logs the result" do
      service = instance_double(SyncCdotPermits, call: "SUCCESS: created=5 updated=0 unchanged=0 (1 pages)")
      allow(SyncCdotPermits).to receive(:new).and_return(service)
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(service).to have_received(:call)
      expect(Rails.logger).to have_received(:info).with(/SUCCESS:.*created=5/)
    end
  end
end
