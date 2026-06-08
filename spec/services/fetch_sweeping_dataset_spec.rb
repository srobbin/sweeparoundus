# frozen_string_literal: true

require "rails_helper"

RSpec.describe FetchSweepingDataset, type: :service do
  let(:id) { "u5ai-3efk" }
  let(:metadata_url) { SweepingDatasets.metadata_url(id) }
  let(:export_url) { SweepingDatasets.schedule_csv_url(id) }

  describe ".metadata" do
    before do
      body = { "name" => "Street Sweeping Schedule - 2026", "rowsUpdatedAt" => 1_750_000_000 }.to_json
      stub_request(:get, metadata_url).to_return(status: 200, body: body, headers: { "Content-Type" => "application/json" })
    end

    it "parses name and rowsUpdatedAt" do
      meta = described_class.metadata(id)

      expect(meta.id).to eq(id)
      expect(meta.name).to eq("Street Sweeping Schedule - 2026")
      expect(meta.rows_updated_at).to eq(Time.zone.at(1_750_000_000))
    end

    it "sends the X-App-Token header when CHICAGO_DATA_PORTAL_APP_TOKEN is set" do
      original = ENV["CHICAGO_DATA_PORTAL_APP_TOKEN"]
      ENV["CHICAGO_DATA_PORTAL_APP_TOKEN"] = "secret-token"
      described_class.metadata(id)
      expect(WebMock).to have_requested(:get, metadata_url).with(headers: { "X-App-Token" => "secret-token" })
    ensure
      ENV["CHICAGO_DATA_PORTAL_APP_TOKEN"] = original
    end
  end

  describe ".download" do
    let(:dest) { Rails.root.join("tmp", "spec", "candidate.csv").to_s }

    after { FileUtils.rm_f(dest) }

    it "writes the response body to dest and returns the path" do
      stub_request(:get, export_url).to_return(status: 200, body: "WARD,SECTION\n01,01\n")

      result = described_class.download(export_url, dest: dest)

      expect(result).to eq(dest)
      expect(File.read(dest)).to eq("WARD,SECTION\n01,01\n")
    end
  end

  describe "error handling" do
    it "raises NotFound on 404 (unpublished dataset)" do
      stub_request(:get, metadata_url).to_return(status: 404, body: "not found")
      expect { described_class.metadata(id) }.to raise_error(FetchSweepingDataset::NotFound)
    end

    it "raises HttpError on a non-retryable 4xx" do
      stub_request(:get, metadata_url).to_return(status: 400, body: "bad request")
      expect { described_class.metadata(id) }.to raise_error(FetchSweepingDataset::HttpError, /HTTP 400/)
    end

    it "retries on 5xx and succeeds when a later attempt returns 200" do
      allow_any_instance_of(described_class).to receive(:sleep)
      stub_request(:get, metadata_url)
        .to_return(status: 503, body: "unavailable").then
        .to_return(status: 200, body: { "name" => "Street Sweeping Schedule - 2026", "rowsUpdatedAt" => 1 }.to_json)

      expect(described_class.metadata(id).name).to eq("Street Sweeping Schedule - 2026")
      expect(WebMock).to have_requested(:get, metadata_url).twice
    end
  end
end
