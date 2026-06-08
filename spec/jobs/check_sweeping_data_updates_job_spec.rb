# frozen_string_literal: true

require "rails_helper"

RSpec.describe CheckSweepingDataUpdatesJob do
  include ActiveSupport::Testing::TimeHelpers

  let(:schedule_path) { "spec/fixtures/sweeping/schedule.csv" }
  let(:zones_path) { "spec/fixtures/sweeping/zones.geojson" }
  let(:committed_schedule) { File.binread(Rails.root.join(schedule_path)) }
  let(:committed_zones) { File.binread(Rails.root.join(zones_path)) }

  let(:config) do
    double(
      "SweepingDatasets::Config",
      schedule_id: "sid",
      zones_id: "zid",
      schedule_path: schedule_path,
      zones_path: zones_path
    )
  end

  let(:pr_service) { instance_double(OpenCandidateDataPr, call: double(number: 1)) }

  before do
    travel_to(Date.new(2026, 6, 15))
    allow(SweepingDatasets).to receive(:for).with(2026).and_return(config)
    allow(FetchSweepingDataset).to receive(:metadata).with("sid")
      .and_return(FetchSweepingDataset::Metadata.new(id: "sid", name: "Street Sweeping Schedule - 2026", rows_updated_at: Time.current))
    allow(FetchSweepingDataset).to receive(:metadata).with("zid")
      .and_return(FetchSweepingDataset::Metadata.new(id: "zid", name: "Street Sweeping Zones - 2026", rows_updated_at: Time.current))
    allow(OpenCandidateDataPr).to receive(:new).and_return(pr_service)
    allow(Sentry).to receive(:capture_message)
  end

  after { travel_back }

  def stub_downloads(schedule:, zones:)
    allow(FetchSweepingDataset).to receive(:download) do |_url, dest:|
      FileUtils.mkdir_p(File.dirname(dest))
      File.binwrite(dest, dest.include?("schedule") ? schedule : zones)
      dest
    end
  end

  context "outside the sweeping season" do
    it "no-ops without touching the datasets or opening a PR" do
      travel_to(Date.new(2026, 1, 15))

      expect(FetchSweepingDataset).not_to receive(:metadata)
      expect(OpenCandidateDataPr).not_to receive(:new)

      described_class.new.perform
    end
  end

  context "when candidates are semantically identical to committed files" do
    before { stub_downloads(schedule: committed_schedule, zones: committed_zones) }

    it "does not open a PR" do
      expect(OpenCandidateDataPr).not_to receive(:new)
      described_class.new.perform
    end
  end

  context "when candidates differ only in export formatting" do
    # Same data as the committed fixtures, but with CSV rows reordered + extra
    # quoting, and GeoJSON features reordered + object keys reordered. The
    # semantic comparison must treat these as unchanged so the City's export
    # formatting never produces a false-positive PR.
    let(:reordered_schedule) do
      <<~CSV
        WARD SECTION (CONCATENATED),WARD,SECTION,MONTH NAME,MONTH NUMBER,DATES
        0102,01,02,APRIL,4,"3,4"
        0101,"01","01",APRIL,4,"1,2"
      CSV
    end

    let(:reordered_zones) do
      parsed = JSON.parse(committed_zones)
      reordered = {
        "features" => parsed["features"].reverse.map { |f|
          {
            "geometry" => { "coordinates" => f["geometry"]["coordinates"], "type" => f["geometry"]["type"] },
            "properties" => f["properties"].sort.to_h,
            "type" => f["type"]
          }
        },
        "type" => parsed["type"]
      }
      JSON.generate(reordered)
    end

    before { stub_downloads(schedule: reordered_schedule, zones: reordered_zones) }

    it "does not open a PR" do
      expect(OpenCandidateDataPr).not_to receive(:new)
      described_class.new.perform
    end
  end

  context "when zones differ only in Socrata row metadata" do
    # The City's GeoJSON export stamps each feature with ":id"/":version"/
    # ":updated_at" row metadata that can change on a republish without any real
    # change. Stripping it must prevent a false-positive (no-op) PR.
    before do
      parsed = JSON.parse(committed_zones)
      parsed["features"].each_with_index do |feature, i|
        feature["properties"] = feature["properties"].merge(
          ":id" => "row-abc#{i}",
          ":version" => "rv-xyz#{i}",
          ":created_at" => "2026-04-08T18:42:39.189Z",
          ":updated_at" => "2026-05-0#{i + 1}T00:00:00.000Z"
        )
      end
      stub_downloads(schedule: committed_schedule, zones: JSON.generate(parsed))
    end

    it "does not open a PR" do
      expect(OpenCandidateDataPr).not_to receive(:new)
      described_class.new.perform
    end
  end

  context "when the schedule differs but zones are unchanged" do
    before do
      changed_schedule = committed_schedule + %(0103,01,03,APRIL,4,"5,6"\n)
      stub_downloads(schedule: changed_schedule, zones: committed_zones)
    end

    it "opens a PR for only the changed file" do
      described_class.new.perform

      expect(pr_service).to have_received(:call) do |branch:, title:, body:, files:|
        expect(files.map { |f| f[:path] }).to eq([ schedule_path ])
        expect(branch).to match(%r{\Adata-update/2026-[0-9a-f]{8}\z})
        expect(title).to include("schedule")
        expect(body).to include("rowsUpdatedAt")
      end
    end
  end

  context "PR body and change summaries" do
    it "summarizes schedule row and ward-section changes" do
      changed_schedule = committed_schedule + %(0103,01,03,APRIL,4,"5,6"\n)
      stub_downloads(schedule: changed_schedule, zones: committed_zones)

      described_class.new.perform

      expect(pr_service).to have_received(:call) do |branch:, title:, body:, files:|
        expect(body).to include("Rows: 2 → 3")
        expect(body).to include("Ward sections added (1): 0103")
      end
    end

    it "opens a PR for only the zones file and summarizes feature changes" do
      parsed = JSON.parse(committed_zones)
      parsed["features"] << {
        "type" => "Feature",
        "properties" => { "ward_section" => "0103", "ward" => "01", "section" => "03" },
        "geometry" => { "type" => "Point", "coordinates" => [ -87.8, 41.7 ] }
      }
      stub_downloads(schedule: committed_schedule, zones: JSON.generate(parsed))

      described_class.new.perform

      expect(pr_service).to have_received(:call) do |branch:, title:, body:, files:|
        expect(files.map { |f| f[:path] }).to eq([ zones_path ])
        expect(body).to include("Ward sections: 2 → 3")
        expect(body).to include("Ward sections added (1): 0103")
      end
    end

    it "truncates long ward-section lists" do
      extra = (1..21).map { |i| format(%(02%02d,02,%02d,APRIL,4,"1,2"\n), i, i) }.join
      stub_downloads(schedule: committed_schedule + extra, zones: committed_zones)

      described_class.new.perform

      expect(pr_service).to have_received(:call) do |branch:, title:, body:, files:|
        expect(body).to include("Ward sections added (21):")
        expect(body).to include("… (+1 more)")
      end
    end
  end

  context "availability guards" do
    it "captures a message and skips when there is no config for the year" do
      allow(SweepingDatasets).to receive(:for).with(2026)
        .and_raise(SweepingDatasets::MissingConfigError.new("No sweeping dataset config for 2026"))

      expect(OpenCandidateDataPr).not_to receive(:new)
      described_class.new.perform

      expect(Sentry).to have_received(:capture_message).with(/No dataset config for 2026/, level: :error)
    end

    it "captures a message and skips when a dataset is not published yet (404)" do
      allow(FetchSweepingDataset).to receive(:metadata).with("sid")
        .and_raise(FetchSweepingDataset::NotFound.new("HTTP 404 for data.cityofchicago.org/api/views/sid.json"))

      expect(OpenCandidateDataPr).not_to receive(:new)
      described_class.new.perform

      expect(Sentry).to have_received(:capture_message).with(/not published yet/, level: :error)
    end

    it "captures a message and skips when the dataset metadata is for the wrong year" do
      allow(FetchSweepingDataset).to receive(:metadata).with("sid")
        .and_return(FetchSweepingDataset::Metadata.new(id: "sid", name: "Street Sweeping Schedule - 2025", rows_updated_at: Time.current))

      expect(OpenCandidateDataPr).not_to receive(:new)
      described_class.new.perform

      expect(Sentry).to have_received(:capture_message).with(/is for 2025, expected 2026/, level: :error)
    end
  end
end
