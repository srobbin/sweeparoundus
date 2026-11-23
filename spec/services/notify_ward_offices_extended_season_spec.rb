# frozen_string_literal: true

require "rails_helper"
require "tmpdir"

RSpec.describe NotifyWardOfficesExtendedSeason, type: :service do
  let(:year) { "2026" }
  let(:csv_path) { Rails.root.join("db", "data", "Ward_Offices_#{year}.csv") }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(csv_path).and_return(true)
  end

  def csv_table(rows, headers: [ "WARD", "ALDERMAN", "EMAIL" ])
    CSV::Table.new(rows.map { |values| CSV::Row.new(headers, values) })
  end

  describe "#call" do
    context "when write is false" do
      subject { described_class.new(write: false, year: year).call }

      before do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table([
            [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org" ],
            [ "2", "Hopkins, Brian", "office@aldermanhopkins.com" ]
          ])
        )
      end

      it "does not send any emails" do
        expect(WardOfficeMailer).not_to receive(:with)
        subject
      end

      it "returns test result string with count" do
        expect(subject).to eq("TEST: 2 ward office(s) would be notified of extended season")
      end
    end

    context "when write is true" do
      subject { service.call }

      let(:service) { described_class.new(write: true, year: year) }
      let(:mailer_dbl) { double(WardOfficeMailer) }
      let(:csv_output) { [] }

      before do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table([
            [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org" ],
            [ "2", "Hopkins, Brian", "office@aldermanhopkins.com" ]
          ])
        )
        allow(WardOfficeMailer).to receive(:with).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:extended_season_notice).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:deliver_later).and_return(double("queued job"))
        allow(service).to receive(:write_table) do |table|
          csv_output.replace([ table.headers ] + table.map { |row| table.headers.map { |h| row[h] } })
        end
      end

      it "sends an email to each ward office" do
        subject
        expect(WardOfficeMailer).to have_received(:with).with(
          name: "La Spata", email: "Ward01@cityofchicago.org", ward: "1"
        )
        expect(WardOfficeMailer).to have_received(:with).with(
          name: "Hopkins", email: "office@aldermanhopkins.com", ward: "2"
        )
        expect(mailer_dbl).to have_received(:extended_season_notice).twice
        expect(mailer_dbl).to have_received(:deliver_later).twice
      end

      it "returns success result string with count" do
        expect(subject).to eq("SUCCESS: 2 ward office(s) notified of extended season")
      end

      it "marks notified offices with EXTENDED_NOTIFIED" do
        subject
        expect(csv_output).to include([ "WARD", "ALDERMAN", "EMAIL", "EXTENDED_NOTIFIED" ])
        expect(csv_output).to include([ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", "true" ])
        expect(csv_output).to include([ "2", "Hopkins, Brian", "office@aldermanhopkins.com", "true" ])
      end

      it "skips offices already marked as notified" do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table([
            [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", " TRUE " ],
            [ "2", "Hopkins, Brian", "office@aldermanhopkins.com", nil ]
          ], headers: [ "WARD", "ALDERMAN", "EMAIL", "EXTENDED_NOTIFIED" ])
        )

        expect(subject).to eq("SUCCESS: 1 ward office(s) notified of extended season")
        expect(WardOfficeMailer).not_to have_received(:with).with(hash_including(ward: "1"))
        expect(mailer_dbl).to have_received(:deliver_later).once
      end

      it "marks only successful enqueues and retries failed offices on the next run" do
        attempts = 0
        allow(mailer_dbl).to receive(:deliver_later) do
          attempts += 1
          raise "Queue unavailable" if attempts == 1
          double("queued job")
        end
        allow(Sentry).to receive(:capture_exception)

        expect(subject).to eq("SUCCESS: 1 ward office(s) notified of extended season")
        expect(csv_output).to include([ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", nil ])
        expect(csv_output).to include([ "2", "Hopkins, Brian", "office@aldermanhopkins.com", "true" ])
        expect(Sentry).to have_received(:capture_exception).once

        persisted = CSV.parse(csv_output.map(&:to_csv).join, headers: true)
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(persisted)
        expect(service.call).to eq("SUCCESS: 1 ward office(s) notified of extended season")
        expect(attempts).to eq(3)
      end

      it "does not mark offices when enqueueing is aborted" do
        allow(mailer_dbl).to receive(:deliver_later).and_return(false)
        allow(Sentry).to receive(:capture_exception)

        expect(subject).to eq("SUCCESS: 0 ward office(s) notified of extended season")
        expect(service).not_to have_received(:write_table)
      end

      it "checkpoints each office before attempting the next enqueue" do
        attempts = 0
        allow(mailer_dbl).to receive(:deliver_later) do
          attempts += 1
          if attempts == 2
            expect(csv_output).to include([ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", "true" ])
            raise Interrupt, "Interrupted"
          end
          double("queued job")
        end

        expect { subject }.to raise_error(Interrupt)
        persisted = CSV.parse(csv_output.map(&:to_csv).join, headers: true)
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(persisted)

        expect(service.call).to eq("SUCCESS: 1 ward office(s) notified of extended season")
        expect(attempts).to eq(3)
      end

      it "stops enqueueing if saving progress fails" do
        allow(service).to receive(:write_table).and_raise(Errno::ENOSPC)

        expect { subject }.to raise_error(Errno::ENOSPC)
        expect(mailer_dbl).to have_received(:deliver_later).once
      end
    end
  end

  describe "atomic CSV persistence" do
    it "replaces the CSV with the complete updated table and preserves permissions" do
      Dir.mktmpdir do |directory|
        path = Pathname.new(directory).join("offices.csv")
        File.write(path, "original")
        File.chmod(0o644, path)
        service = described_class.new
        allow(service).to receive(:csv_path).and_return(path)
        table = csv_table([ [ "1", "La Spata, Daniel", "ward@example.com" ] ])

        service.send(:write_table, table)

        expect(CSV.read(path, headers: true).first["EMAIL"]).to eq("ward@example.com")
        expect(File.stat(path).mode & 0o777).to eq(0o644)
        expect(Dir.children(directory)).to eq([ "offices.csv" ])
      end
    end

    it "leaves the original CSV intact and cleans up if replacement fails" do
      Dir.mktmpdir do |directory|
        path = Pathname.new(directory).join("offices.csv")
        File.write(path, "original")
        service = described_class.new
        allow(service).to receive(:csv_path).and_return(path)
        allow(File).to receive(:rename).and_raise(Errno::EACCES)

        expect { service.send(:write_table, csv_table([ [ "1", "Name", "ward@example.com" ] ])) }.to raise_error(Errno::EACCES)
        expect(File.read(path)).to eq("original")
        expect(Dir.children(directory)).to eq([ "offices.csv" ])
      end
    end
  end
end
