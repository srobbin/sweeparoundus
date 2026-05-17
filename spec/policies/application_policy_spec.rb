require "rails_helper"

RSpec.describe ApplicationPolicy do
  let(:user) { double(:user) }
  let(:record) { double(:record) }
  let(:policy) { described_class.new(user, record) }

  describe "#index?" do
    it "returns true" do
      expect(policy.index?).to be true
    end
  end

  describe "#show?" do
    it "returns false" do
      expect(policy.show?).to be false
    end
  end

  describe "#create?" do
    it "returns false" do
      expect(policy.create?).to be false
    end
  end

  describe "#new?" do
    it "delegates to create?" do
      expect(policy.new?).to eq(policy.create?)
    end
  end

  describe "#update?" do
    it "returns false" do
      expect(policy.update?).to be false
    end
  end

  describe "#edit?" do
    it "delegates to update?" do
      expect(policy.edit?).to eq(policy.update?)
    end
  end

  describe "#destroy?" do
    it "returns false" do
      expect(policy.destroy?).to be false
    end
  end

  describe ApplicationPolicy::Scope do
    it "resolves to all records" do
      scope = double(:scope)
      allow(scope).to receive(:all).and_return([ :record ])

      resolved = described_class.new(user, scope).resolve

      expect(resolved).to eq([ :record ])
    end
  end
end
