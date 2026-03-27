require "rails_helper"

RSpec.describe AreaDecorator do
  let(:area) { create(:area) }
  let(:decorated_area) { area.decorate }
  let(:today) { Time.current.to_date }

  describe "#next_sweep" do
    context "with an upcoming sweep with multiple dates" do
      before do
        create(:sweep, area: area, date_1: today + 10, date_2: today + 11, date_3: today + 12, date_4: nil)
      end

      it "returns formatted dates separated by slashes" do
        result = decorated_area.next_sweep

        expect(result).to include((today + 10).strftime("%B %-d"))
        expect(result).to include((today + 11).strftime("%B %-d"))
        expect(result).to include((today + 12).strftime("%B %-d"))
        expect(result).to include(" / ")
      end

      it "excludes nil dates" do
        result = decorated_area.next_sweep
        date_parts = result.split(" / ")

        expect(date_parts.length).to eq(3)
      end
    end

    context "with no upcoming sweeps" do
      it "returns the fallback message" do
        expect(decorated_area.next_sweep).to eq("No sweeps scheduled in the near future.")
      end
    end

    context "with a single-date sweep" do
      before { create(:sweep, area: area, date_1: today + 5, date_2: nil, date_3: nil, date_4: nil) }

      it "returns a single formatted date" do
        result = decorated_area.next_sweep

        expect(result).to eq((today + 5).strftime("%B %-d"))
        expect(result).not_to include("/")
      end
    end
  end
end
