# frozen_string_literal: true

require 'rails_helper'

RSpec.describe NotifyWardOfficesDelayed, type: :service do
  let(:year) { "2026" }
  let(:csv_path) { Rails.root.join("db", "data", "Ward_Offices_#{year}.csv") }

  before do
    allow(File).to receive(:exist?).and_call_original
    allow(File).to receive(:exist?).with(csv_path).and_return(true)
  end

  def csv_table(rows, headers: [ "WARD", "ALDERMAN", "EMAIL" ])
    CSV::Table.new(rows.map { |values| CSV::Row.new(headers, values) })
  end

  describe '#call' do
    context 'when write is false' do
      subject { described_class.new(write: false, year: year).call }

      before do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table([
            [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org" ],
            [ "2", "Hopkins, Brian", "office@aldermanhopkins.com" ]
          ])
        )
      end

      it 'does not send any emails' do
        expect(WardOfficeMailer).not_to receive(:with)
        subject
      end

      it 'returns test result string with count' do
        expect(subject).to eq("TEST: 2 ward office(s) would be notified of delay")
      end
    end

    context 'when write is true' do
      subject { described_class.new(write: true, year: year).call }

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
        allow(mailer_dbl).to receive(:sweeping_data_delayed).and_return(mailer_dbl)
        allow(mailer_dbl).to receive(:deliver_later)
        allow(CSV).to receive(:open).and_yield(csv_output)
      end

      it 'sends an email to each ward office' do
        subject
        expect(WardOfficeMailer).to have_received(:with).with(
          name: "La Spata", email: "Ward01@cityofchicago.org", ward: "1"
        )
        expect(WardOfficeMailer).to have_received(:with).with(
          name: "Hopkins", email: "office@aldermanhopkins.com", ward: "2"
        )
        expect(mailer_dbl).to have_received(:sweeping_data_delayed).twice
        expect(mailer_dbl).to have_received(:deliver_later).twice
      end

      it 'returns success result string with count' do
        expect(subject).to eq("SUCCESS: 2 ward office(s) notified of delay")
      end

      it 'logs progress for each delivery' do
        expect { subject }.to output(
          /1\/2 notifying Ward 1.*\n2\/2 notifying Ward 2/
        ).to_stdout
      end

      it 'marks notified offices in the CSV with DELAY_NOTIFIED' do
        subject
        expect(csv_output).to include([ "WARD", "ALDERMAN", "EMAIL", "DELAY_NOTIFIED" ])
        expect(csv_output).to include([ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", "true" ])
        expect(csv_output).to include([ "2", "Hopkins, Brian", "office@aldermanhopkins.com", "true" ])
      end
    end

    context 'when a row has already been notified of delay' do
      let(:headers) { [ "WARD", "ALDERMAN", "EMAIL", "DELAY_NOTIFIED" ] }

      before do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table(
            [
              [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", "true" ],
              [ "2", "Hopkins, Brian", "office@aldermanhopkins.com", nil ]
            ],
            headers: headers,
          )
        )
      end

      context 'with write false' do
        subject { described_class.new(write: false, year: year).call }

        it 'skips already-notified rows' do
          expect(subject).to eq("TEST: 1 ward office(s) would be notified of delay")
        end

        it 'logs the skipped count' do
          expect { subject }.to output(/1 office\(s\) already notified of delay, skipping/).to_stdout
        end
      end

      context 'with write true' do
        subject { described_class.new(write: true, year: year).call }

        let(:mailer_dbl) { double(WardOfficeMailer) }
        let(:csv_output) { [] }

        before do
          allow(WardOfficeMailer).to receive(:with).and_return(mailer_dbl)
          allow(mailer_dbl).to receive(:sweeping_data_delayed).and_return(mailer_dbl)
          allow(mailer_dbl).to receive(:deliver_later)
          allow(CSV).to receive(:open).and_yield(csv_output)
        end

        it 'only sends to the non-notified office' do
          subject
          expect(WardOfficeMailer).to have_received(:with).once.with(
            name: "Hopkins", email: "office@aldermanhopkins.com", ward: "2"
          )
        end

        it 'preserves existing DELAY_NOTIFIED flags and marks new ones' do
          subject
          expect(csv_output).to include([ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", "true" ])
          expect(csv_output).to include([ "2", "Hopkins, Brian", "office@aldermanhopkins.com", "true" ])
        end
      end
    end

    context 'when all rows have already been notified of delay' do
      subject { described_class.new(write: true, year: year).call }

      before do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table(
            [
              [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org", "true" ],
              [ "2", "Hopkins, Brian", "office@aldermanhopkins.com", "true" ]
            ],
            headers: [ "WARD", "ALDERMAN", "EMAIL", "DELAY_NOTIFIED" ],
          )
        )
      end

      it 'does not send any emails' do
        expect(WardOfficeMailer).not_to receive(:with)
        subject
      end

      it 'does not rewrite the CSV' do
        expect(CSV).not_to receive(:open)
        subject
      end

      it 'returns success with zero count' do
        expect(subject).to eq("SUCCESS: 0 ward office(s) notified of delay")
      end
    end

    context 'when a row has a blank email' do
      subject { described_class.new(write: false, year: year).call }

      before do
        allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
          csv_table([
            [ "1", "La Spata, Daniel", "Ward01@cityofchicago.org" ],
            [ "2", "Hopkins, Brian", "" ]
          ])
        )
      end

      it 'skips rows with blank emails' do
        expect(subject).to eq("TEST: 1 ward office(s) would be notified of delay")
      end
    end

    context 'when CSV file is not found' do
      subject { described_class.new(write: false, year: "1999").call }

      it 'raises an error' do
        expect { subject }.to raise_error(RuntimeError, /CSV not found/)
      end
    end

    context 'when required ENV vars are missing' do
      subject { described_class.new(write: false, year: year).call }

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
