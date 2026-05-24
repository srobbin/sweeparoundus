# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SeedYearlyData, type: :model do
  describe '#call' do
    let!(:sweep) { create(:sweep) }
    let(:year) { Time.current.year.to_s }

    subject { described_class.new(write: write, year: year).call }

    context 'when write is false' do
      let(:write) { false }

      before do
        allow_any_instance_of(described_class).to receive(:import_geojson_data)
        allow_any_instance_of(described_class).to receive(:import_schedule_data)
      end

      it 'does not change the count of Sweep and Area' do
        expect { subject }.not_to change { Sweep.count }
        expect { subject }.not_to change { Area.count }
      end

      it 'returns a test message' do
        expect(subject).to eq("TEST: 1 sweeps and 1 areas to be deleted; geojson and schedule files opened without error")
      end

      context 'when an error occurs' do
        before do
          allow_any_instance_of(described_class).to receive(:import_geojson_data).and_raise(StandardError.new('Uh oh'))
        end

        it 'returns an error message' do
          expect(subject).to eq('TEST ERROR: Uh oh')
        end

        it 'does not change the count of Sweep and Area' do
          expect { subject }.not_to change { Sweep.count }
          expect { subject }.not_to change { Area.count }
        end
      end
    end

    context 'when write is true' do
      let(:write) { true }

      before do
        allow_any_instance_of(described_class).to receive(:destroy_old_sweep_data)
        allow_any_instance_of(described_class).to receive(:destroy_old_area_data)
        allow_any_instance_of(described_class).to receive(:import_geojson_data)
        allow_any_instance_of(described_class).to receive(:import_schedule_data)
      end

      context 'when an error occurs' do
        before do
          allow_any_instance_of(described_class).to receive(:import_geojson_data).and_raise(StandardError.new('Test error'))
        end

        it 'returns an error message' do
          expect(subject).to eq('ERROR: Failed to seed yearly data - Test error')
        end

        it 'does not change the count of Sweep and Area' do
          expect { subject }.not_to change { Sweep.count }
          expect { subject }.not_to change { Area.count }
        end
      end

      context 'when skip_geojson is true' do
        subject { described_class.new(write: true, year: year, skip_geojson: true).call }

        it 'does not destroy areas or import the geojson' do
          expect_any_instance_of(described_class).not_to receive(:destroy_old_area_data)
          expect_any_instance_of(described_class).not_to receive(:import_geojson_data)
          subject
        end

        it 'preserves existing Area records' do
          expect { subject }.not_to change { Area.count }
        end

        it 'returns a schedule-only success message' do
          expect(subject).to match(/\ASUCCESS: \d+ sweeps re-created from .* schedule file \(areas unchanged\)\z/)
        end
      end

      context 'file year' do
        before do
          allow_any_instance_of(described_class).to receive(:destroy_old_sweep_data).and_call_original
          allow_any_instance_of(described_class).to receive(:destroy_old_area_data).and_call_original
          allow_any_instance_of(described_class).to receive(:import_geojson_data).and_call_original
          allow_any_instance_of(described_class).to receive(:import_schedule_data).and_call_original
        end

        describe 'when files exist for arg year' do
          let(:year) { '2024' }

          it 'returns a success message' do
            expect(subject).to include('SUCCESS')
          end

          # The 2024 CSV has Ward 1 Section 9 sweeping Sep 30 and Oct 1.
          # Pre-fix those landed in two separate Sweep records (each with
          # only date_1 filled) because clustering ran per-month. The fix
          # gathers an area's dates across the whole year before
          # clustering, so the pair should now land in a single Sweep.
          it 'merges month-boundary pairs into a single Sweep' do
            subject
            area = Area.find_by(ward: 1, number: 9)
            current_year = Date.current.year

            sep_30 = Date.new(current_year, 9, 30)
            oct_01 = Date.new(current_year, 10, 1)

            merged_sweep = area.sweeps.find_by(date_1: sep_30, date_2: oct_01)
            expect(merged_sweep).to be_present
            expect(area.sweeps.where(date_1: sep_30, date_2: nil)).to be_empty
            expect(area.sweeps.where(date_1: oct_01, date_2: nil)).to be_empty
          end
        end

        describe 'when files do not exist for arg year' do
          let(:year) { '2022' }

          it 'returns an error message' do
            expect(subject).to eq("ERROR: Failed to seed yearly data - No such file or directory @ rb_sysopen - db/data/Street Sweeping Zones - #{year}.geojson")
          end

          it 'does not change the count of Sweep and Area' do
            expect { subject }.not_to change { Sweep.count }
            expect { subject }.not_to change { Area.count }
          end
        end
      end
    end
  end

  describe '#cluster_dates' do
    let(:service) { described_class.new(write: false, year: '2026') }

    def call(*dates)
      service.send(:cluster_dates, dates)
    end

    it 'returns no clusters for an empty input' do
      expect(call).to eq([])
    end

    it 'groups dates that are within 3 days of each other' do
      apr_1 = Date.new(2026, 4, 1)
      apr_2 = Date.new(2026, 4, 2)

      expect(call(apr_1, apr_2)).to eq([ [ apr_1, apr_2 ] ])
    end

    it 'splits dates that are more than 3 days apart' do
      apr_1 = Date.new(2026, 4, 1)
      apr_5 = Date.new(2026, 4, 5)

      expect(call(apr_1, apr_5)).to eq([ [ apr_1 ], [ apr_5 ] ])
    end

    it 'merges a month-boundary pair into a single cluster' do
      jun_30 = Date.new(2026, 6, 30)
      jul_01 = Date.new(2026, 7, 1)

      expect(call(jun_30, jul_01)).to eq([ [ jun_30, jul_01 ] ])
    end

    it 'merges a month-boundary triple into a single 3-date cluster' do
      jul_31 = Date.new(2026, 7, 31)
      aug_01 = Date.new(2026, 8, 1)
      aug_03 = Date.new(2026, 8, 3)

      expect(call(jul_31, aug_01, aug_03)).to eq([ [ jul_31, aug_01, aug_03 ] ])
    end

    it 'splits non-adjacent dates that straddle a month boundary' do
      jun_28 = Date.new(2026, 6, 28)
      jul_05 = Date.new(2026, 7, 5)

      expect(call(jun_28, jul_05)).to eq([ [ jun_28 ], [ jul_05 ] ])
    end

    it 'preserves the standard monthly cadence (Ward 2 Area 4 style)' do
      dates = [ 1, 7, 8, 14, 15, 21, 22, 28, 29 ].map { |d| Date.new(2026, 4, d) }
      clusters = service.send(:cluster_dates, dates)

      expect(clusters.map(&:size)).to eq([ 1, 2, 2, 2, 2 ])
    end

    it 'produces a 4-date cluster for a dense Lincoln Park style stretch' do
      # Ward 11 Area 2 April 2026: sweeps run Apr 3, 6, 7, 8 (3-day gaps).
      dates = [ 3, 6, 7, 8 ].map { |d| Date.new(2026, 4, d) }
      clusters = service.send(:cluster_dates, dates)

      expect(clusters.length).to eq(1)
      expect(clusters.first.length).to eq(4)
    end
  end

  describe '#collect_area_dates' do
    let(:service) { described_class.new(write: false, year: '2026') }
    let!(:area) { create(:area, ward: 99, number: 99, shortcode: 'W99A99', slug: 'ward-99-sweep-area-99') }

    before do
      rows = [
        CSV::Row.new(
          [ 'WARD SECTION (CONCATENATED)', 'WARD', 'SECTION', 'MONTH NAME', 'MONTH NUMBER', 'DATES' ],
          [ '9999', '99', '99', 'JUNE', '6', '30' ]
        ),
        CSV::Row.new(
          [ 'WARD SECTION (CONCATENATED)', 'WARD', 'SECTION', 'MONTH NAME', 'MONTH NUMBER', 'DATES' ],
          [ '9999', '99', '99', 'JULY', '7', '1' ]
        )
      ]
      allow(CSV).to receive(:foreach).and_yield(rows[0]).and_yield(rows[1])
    end

    it "concatenates an area's dates across all its CSV rows so cross-month dates can later cluster together" do
      current_year = Date.current.year
      expect(service.send(:collect_area_dates)[area]).to eq(
        [ Date.new(current_year, 6, 30), Date.new(current_year, 7, 1) ]
      )
    end
  end

  describe 'import_schedule_data idempotency' do
    let!(:area) { create(:area, ward: 99, number: 99, shortcode: 'W99A99', slug: 'ward-99-sweep-area-99') }
    let(:service) { described_class.new(write: true, year: '2026') }

    before do
      rows = [
        CSV::Row.new(
          [ 'WARD SECTION (CONCATENATED)', 'WARD', 'SECTION', 'MONTH NAME', 'MONTH NUMBER', 'DATES' ],
          [ '9999', '99', '99', 'JUNE', '6', '30' ]
        ),
        CSV::Row.new(
          [ 'WARD SECTION (CONCATENATED)', 'WARD', 'SECTION', 'MONTH NAME', 'MONTH NUMBER', 'DATES' ],
          [ '9999', '99', '99', 'JULY', '7', '1' ]
        )
      ]
      allow(CSV).to receive(:foreach).and_yield(rows[0]).and_yield(rows[1])
    end

    it 'creates the same Sweep set when re-run without destroying in between' do
      service.send(:import_schedule_data)
      original = Sweep.pluck(:area_id, :date_1, :date_2, :date_3, :date_4).sort

      expect { service.send(:import_schedule_data) }.not_to change { Sweep.count }
      expect(Sweep.pluck(:area_id, :date_1, :date_2, :date_3, :date_4).sort).to eq(original)
    end
  end
end
