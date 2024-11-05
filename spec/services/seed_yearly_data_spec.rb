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
end