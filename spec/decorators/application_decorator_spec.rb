require "rails_helper"

RSpec.describe ApplicationDecorator do
  let(:area) { create(:area) }
  let(:decorated) { area.decorate }

  describe "delegation" do
    it "delegates model attribute readers to the wrapped object" do
      expect(decorated.name).to eq(area.name)
      expect(decorated.id).to eq(area.id)
    end

    it "delegates persisted? to the wrapped object" do
      expect(decorated.persisted?).to eq(true)
    end

    it "delegates respond_to? for model methods" do
      expect(decorated).to respond_to(:name)
      expect(decorated).to respond_to(:shortcode)
    end
  end

  describe "#object" do
    it "returns the original unwrapped record" do
      expect(decorated.object).to equal(area)
    end
  end

  describe "#session" do
    it "defaults to an empty hash" do
      expect(decorated.session).to eq({})
    end

    it "stores the session passed at initialization" do
      d = AreaDecorator.new(area, session: { foo: "bar" })
      expect(d.session).to eq({ foo: "bar" })
    end

    it "coerces nil session to an empty hash" do
      d = AreaDecorator.new(area, session: nil)
      expect(d.session).to eq({})
    end
  end

  describe "view helper availability" do
    it "has access to image_tag from ActionView" do
      expect(decorated).to respond_to(:image_tag)
    end

    it "has access to content_tag from ActionView" do
      expect(decorated).to respond_to(:content_tag)
    end
  end

  describe "equality" do
    it "delegates == to the wrapped object so decorator equals the record" do
      expect(decorated == area).to eq(true)
    end

    it "compares decorators by their underlying record via #object" do
      other = area.decorate
      expect(decorated.object).to eq(other.object)
    end
  end
end
