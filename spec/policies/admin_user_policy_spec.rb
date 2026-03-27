require "rails_helper"

RSpec.describe AdminUserPolicy do
  let(:current_user) { double(:admin_user) }
  let(:other_user) { double(:admin_user) }

  describe "#create?" do
    it "returns true" do
      policy = described_class.new(current_user, other_user)

      expect(policy.create?).to be true
    end
  end

  describe "#update?" do
    it "returns true" do
      policy = described_class.new(current_user, other_user)

      expect(policy.update?).to be true
    end
  end

  describe "#destroy?" do
    it "allows destroying other users" do
      policy = described_class.new(current_user, other_user)

      expect(policy.destroy?).to be true
    end

    it "prevents destroying self" do
      policy = described_class.new(current_user, current_user)

      expect(policy.destroy?).to be false
    end
  end
end
