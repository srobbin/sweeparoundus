require "rails_helper"

RSpec.describe Sweep do
  let!(:area) { create(:area) }

  describe "validations" do
    it "is valid with date_1 and an area" do
      sweep = Sweep.new(area: area, date_1: Date.tomorrow)

      expect(sweep).to be_valid
    end

    it "is invalid without date_1" do
      sweep = Sweep.new(area: area, date_1: nil)

      expect(sweep).not_to be_valid
      expect(sweep.errors[:date_1]).to include("can't be blank")
    end

    it "is invalid with a duplicate date_1 for the same area" do
      create(:sweep, area: area, date_1: Date.tomorrow)
      duplicate = Sweep.new(area: area, date_1: Date.tomorrow)

      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:date_1]).to include("has already been taken")
    end

    it "allows the same date_1 for different areas" do
      create(:sweep, area: area, date_1: Date.tomorrow)

      other_area = Area.create!(
        number: 8, ward: 28, shortcode: "W28A8",
        shape: area.shape
      )
      sweep = Sweep.new(area: other_area, date_1: Date.tomorrow)

      expect(sweep).to be_valid
    end
  end

  describe "associations" do
    it "belongs to an area" do
      sweep = create(:sweep, area: area)

      expect(sweep.area).to eq(area)
    end

    it "accesses alerts through area" do
      sweep = create(:sweep, area: area)
      alert = create(:alert, :confirmed, area: area)

      expect(sweep.alerts).to include(alert)
    end
  end
end
