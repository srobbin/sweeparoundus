# frozen_string_literal: true

require "rails_helper"

RSpec.describe CleanupStaleCdotPermitsJob do
  describe "#perform" do
    it "delegates to CleanupStaleCdotPermits and logs the result" do
      service = instance_double(CleanupStaleCdotPermits, call: "SUCCESS: deleted 3 stale permit(s) (expired before 2026-05-04T05:00:00Z)")
      allow(CleanupStaleCdotPermits).to receive(:new).and_return(service)
      allow(Rails.logger).to receive(:info)

      described_class.new.perform

      expect(service).to have_received(:call)
      expect(Rails.logger).to have_received(:info).with(/SUCCESS:.*deleted 3/)
    end
  end
end
