require "rails_helper"

RSpec.describe Decoratable do
  let(:area) { create(:area) }
  let(:sweep) { create(:sweep, area: area) }

  describe "#decorate" do
    it "returns the matching decorator for an Area" do
      expect(area.decorate).to be_a(AreaDecorator)
    end

    it "returns the matching decorator for a Sweep" do
      expect(sweep.decorate).to be_a(SweepDecorator)
    end

    it "wraps the original record so delegated methods still work" do
      decorated = area.decorate
      expect(decorated.name).to eq(area.name)
      expect(decorated.shortcode).to eq(area.shortcode)
    end

    it "passes session data through to the decorator" do
      session = { search_lat: 41.886, search_lng: -87.706 }
      decorated = area.decorate(session: session)

      expect(decorated.session).to eq(session)
    end

    it "defaults session to an empty hash when not provided" do
      expect(area.decorate.session).to eq({})
    end

    it "provides access to the unwrapped record via #object" do
      decorated = area.decorate
      expect(decorated.object).to eq(area)
      expect(decorated.object).to be_a(Area)
    end

    it "raises NotImplementedError for a model without a decorator class" do
      stub_const("Widget", Class.new(ApplicationRecord) { self.table_name = "areas" })

      widget = Widget.first || Widget.new
      expect { widget.decorate }.to raise_error(
        NotImplementedError, /No decorator defined for Widget/
      )
    end
  end
end
