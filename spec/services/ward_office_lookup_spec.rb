# frozen_string_literal: true

require "rails_helper"

RSpec.describe WardOfficeLookup, type: :service do
  let(:csv_path) { Rails.root.join("db", "data", "Ward_Offices_2026.csv") }

  def csv_table(rows, headers: [ "WARD", "ALDERMAN", "WARD PHONE", "EMAIL", "WEBSITE" ])
    CSV::Table.new(rows.map { |values| CSV::Row.new(headers, values) })
  end

  describe ".for_ward" do
    before do
      allow(CSV).to receive(:read).with(csv_path, headers: true).and_return(
        csv_table([
          [ "1", "La Spata, Daniel", "(872) 206-2685", "Ward01@cityofchicago.org", "https://www.the1stward.com/" ],
          [ "2", "Hopkins, Brian", "(312) 744-6836", "office@aldermanhopkins.com", "https://www.aldermanhopkins.com/" ]
        ])
      )
    end

    it "returns name and contact info with first-last name formatting" do
      expect(described_class.for_ward("1", year: "2026")).to eq(
        ward: "1",
        alderperson: "Daniel La Spata",
        phone: "(872) 206-2685",
        email: "Ward01@cityofchicago.org",
        website: "https://www.the1stward.com/"
      )
    end

    it "returns nil for an unknown ward" do
      expect(described_class.for_ward("99", year: "2026")).to be_nil
    end

    it "returns nil for a blank ward" do
      expect(described_class.for_ward(nil, year: "2026")).to be_nil
    end
  end
end
