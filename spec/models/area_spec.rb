require 'rails_helper'

RSpec.describe Area do
  describe '#next_sweep' do
    let(:area) { create(:area) }
    let(:today) { Time.current.to_date }
    let(:future_sweep) { create(:sweep, area: area, date_1: today + 30, date_2: today + 31) }

    shared_examples 'returns the ongoing sweep' do
      it 'returns the ongoing sweep' do
        expect(area.next_sweep).to eq(ongoing_sweep)
      end
    end

    context 'with ongoing sweep' do
      context 'when today is the first day of sweep' do
        let!(:ongoing_sweep) { create(:sweep, area: area, date_1: today, date_2: today + 1, date_3: nil, date_4: nil) }

        include_examples 'returns the ongoing sweep'
      end

      context 'when today is the second day of four-day sweep' do
        let!(:ongoing_sweep) { create(:sweep, area: area, date_1: today - 1, date_2: today, date_3: today + 1, date_4: today + 2) }

        include_examples 'returns the ongoing sweep'
      end

      context 'when today is the second day of two-day sweep' do
        let!(:ongoing_sweep) { create(:sweep, area: area, date_1: today - 1, date_2: today, date_3: nil, date_4: nil) }

        include_examples 'returns the ongoing sweep'
      end

      context 'when today is the fourth day of four-day sweep' do
        let!(:ongoing_sweep) { create(:sweep, area: area, date_1: today - 3, date_2: today - 2, date_3: today - 1, date_4: today) }

        include_examples 'returns the ongoing sweep'
      end
    end

    context 'with no ongoing sweep but there are multiple future sweeps' do
      let!(:next_sweep) { create(:sweep, area: area, date_1: today + 1, date_2: today + 2, date_3: nil, date_4: nil) }

      it 'returns the next future sweep' do
        expect(area.next_sweep).to eq(next_sweep)
      end
    end

    context 'with no ongoing or future sweeps' do
      it 'returns nil' do
        expect(area.next_sweep).to be_nil
      end
    end
  end
end
