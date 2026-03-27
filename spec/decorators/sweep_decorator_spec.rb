require "rails_helper"

RSpec.describe SweepDecorator do
  let(:area) { create(:area) }

  describe "date formatting" do
    context "with all dates present" do
      let(:sweep) do
        create(:sweep, area: area,
          date_1: Date.new(2026, 5, 15),
          date_2: Date.new(2026, 5, 16),
          date_3: Date.new(2026, 5, 17),
          date_4: Date.new(2026, 5, 18)
        ).decorate
      end

      it "formats date_1" do
        expect(sweep.date_1).to eq("May 15")
      end

      it "formats date_2" do
        expect(sweep.date_2).to eq("May 16")
      end

      it "formats date_3" do
        expect(sweep.date_3).to eq("May 17")
      end

      it "formats date_4" do
        expect(sweep.date_4).to eq("May 18")
      end
    end

    context "with nil dates" do
      let(:sweep) do
        create(:sweep, area: area,
          date_1: Date.new(2026, 5, 15),
          date_2: nil,
          date_3: nil,
          date_4: nil
        ).decorate
      end

      it "returns an em dash for nil date_2" do
        expect(sweep.date_2).to eq("—")
      end

      it "returns an em dash for nil date_3" do
        expect(sweep.date_3).to eq("—")
      end

      it "returns an em dash for nil date_4" do
        expect(sweep.date_4).to eq("—")
      end
    end
  end
end
