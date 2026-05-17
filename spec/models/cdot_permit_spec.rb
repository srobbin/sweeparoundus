# frozen_string_literal: true

require "rails_helper"

RSpec.describe CdotPermit do
  describe "validations" do
    it "is valid with a unique_key" do
      permit = build(:cdot_permit)
      expect(permit).to be_valid
    end

    it "is invalid without a unique_key" do
      permit = build(:cdot_permit, unique_key: nil)
      expect(permit).not_to be_valid
      expect(permit.errors[:unique_key]).to include("can't be blank")
    end

    it "is invalid with a duplicate unique_key" do
      create(:cdot_permit, unique_key: "9999999")
      permit = build(:cdot_permit, unique_key: "9999999")
      expect(permit).not_to be_valid
      expect(permit.errors[:unique_key]).to include("has already been taken")
    end
  end

  describe "scopes" do
    let!(:open_future) do
      create(:cdot_permit, application_status: "Open", application_start_date: 5.days.from_now)
    end
    let!(:closed_past) do
      create(:cdot_permit, application_status: "Closed", application_start_date: 5.days.ago)
    end
    let!(:open_past) do
      create(:cdot_permit, application_status: "Open", application_start_date: 2.days.ago)
    end

    describe ".with_open_status" do
      it "returns only permits with application_status 'Open'" do
        expect(CdotPermit.with_open_status).to include(open_future, open_past)
        expect(CdotPermit.with_open_status).not_to include(closed_past)
      end
    end

    describe ".starting_after" do
      it "returns permits with application_start_date after the given time" do
        expect(CdotPermit.starting_after(Time.current)).to include(open_future)
        expect(CdotPermit.starting_after(Time.current)).not_to include(closed_past, open_past)
      end
    end
  end

  describe "#segment_label" do
    it "renders a hyphenated range for distinct from/to numbers" do
      permit = build(:cdot_permit, street_number_from: 3300, street_number_to: 3350,
                     direction: "N", street_name: "CALIFORNIA", suffix: "AVE")
      expect(permit.segment_label).to eq("3300-3350 N CALIFORNIA AVE")
    end

    it "uses a single number when from == to" do
      permit = build(:cdot_permit, street_number_from: 3300, street_number_to: 3300,
                     direction: "N", street_name: "CALIFORNIA", suffix: "AVE")
      expect(permit.segment_label).to eq("3300 N CALIFORNIA AVE")
    end

    it "uses whichever number is present when only one is set" do
      permit = build(:cdot_permit, street_number_from: 3300, street_number_to: nil,
                     direction: "N", street_name: "CALIFORNIA", suffix: "AVE")
      expect(permit.segment_label).to eq("3300 N CALIFORNIA AVE")
    end

    it "omits the suffix when blank" do
      permit = build(:cdot_permit, street_number_from: 3300, street_number_to: 3350,
                     direction: "N", street_name: "CALIFORNIA", suffix: nil)
      expect(permit.segment_label).to eq("3300-3350 N CALIFORNIA")
    end

    it "returns nil if direction or street_name is missing" do
      expect(build(:cdot_permit, direction: nil).segment_label).to be_nil
      expect(build(:cdot_permit, street_name: nil).segment_label).to be_nil
    end

    it "returns nil if neither street number is present" do
      permit = build(:cdot_permit, street_number_from: nil, street_number_to: nil)
      expect(permit.segment_label).to be_nil
    end
  end

  describe "#display_street" do
    it "title-cases the street name and the suffix abbreviation" do
      permit = build(:cdot_permit, direction: "N", street_name: "ROCKWELL", suffix: "ST")
      expect(permit.display_street).to eq("Rockwell St")
    end

    it "title-cases AVE without expanding it" do
      permit = build(:cdot_permit, direction: "N", street_name: "CALIFORNIA", suffix: "AVE")
      expect(permit.display_street).to eq("California Ave")
    end

    it "drops the directional prefix entirely" do
      permit = build(:cdot_permit, direction: "S", street_name: "ASHLAND", suffix: "AVE")
      expect(permit.display_street).not_to include("S ")
    end

    it "omits the suffix when blank" do
      permit = build(:cdot_permit, direction: "N", street_name: "BROADWAY", suffix: nil)
      expect(permit.display_street).to eq("Broadway")
    end

    it "returns nil when the street name is missing" do
      permit = build(:cdot_permit, street_name: nil, suffix: "ST")
      expect(permit.display_street).to be_nil
    end

    it "title-cases multi-word street names" do
      permit = build(:cdot_permit, direction: "S", street_name: "MARTIN LUTHER KING", suffix: "DR")
      expect(permit.display_street).to eq("Martin Luther King Dr")
    end

    it "keeps ordinal suffixes attached to numbered streets" do
      expect(build(:cdot_permit, street_name: "60TH", suffix: "ST").display_street).to eq("60th St")
      expect(build(:cdot_permit, street_name: "83RD", suffix: "ST").display_street).to eq("83rd St")
      expect(build(:cdot_permit, street_name: "18TH", suffix: "ST").display_street).to eq("18th St")
      expect(build(:cdot_permit, street_name: "113TH", suffix: "PL").display_street).to eq("113th Pl")
      expect(build(:cdot_permit, street_name: "1ST", suffix: "AVE").display_street).to eq("1st Ave")
      expect(build(:cdot_permit, street_name: "2ND", suffix: "ST").display_street).to eq("2nd St")
    end
  end
end
