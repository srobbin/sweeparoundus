require "rails_helper"

RSpec.describe Admin::BasePolicy do
  let(:user) { double(:admin_user) }
  let(:record) { double(:record) }
  let(:policy) { described_class.new(user, record) }

  describe "#create?" do
    it "returns true" do
      expect(policy.create?).to be true
    end
  end

  describe "#update?" do
    it "returns true" do
      expect(policy.update?).to be true
    end
  end

  describe Admin::BasePolicy::Scope do
    it "resolves to all records" do
      scope = double(:scope)
      allow(scope).to receive(:all).and_return([:record])

      resolved = described_class.new(user, scope).resolve

      expect(resolved).to eq([:record])
    end
  end
end

RSpec.describe Admin::AlertPolicy do
  let(:user) { double(:admin_user) }
  let(:record) { double(:record) }
  let(:policy) { described_class.new(user, record) }

  describe "#destroy?" do
    it "returns true" do
      expect(policy.destroy?).to be true
    end
  end

  it "inherits create? from BasePolicy" do
    expect(policy.create?).to be true
  end

  it "inherits update? from BasePolicy" do
    expect(policy.update?).to be true
  end
end

RSpec.describe Admin::SweepPolicy do
  let(:user) { double(:admin_user) }
  let(:record) { double(:record) }
  let(:policy) { described_class.new(user, record) }

  it "inherits create? from BasePolicy" do
    expect(policy.create?).to be true
  end

  it "inherits update? from BasePolicy" do
    expect(policy.update?).to be true
  end
end

RSpec.describe Admin::AdminUserPolicy do
  let(:user) { double(:admin_user) }
  let(:record) { double(:record) }
  let(:policy) { described_class.new(user, record) }

  it "inherits create? from BasePolicy" do
    expect(policy.create?).to be true
  end

  it "inherits update? from BasePolicy" do
    expect(policy.update?).to be true
  end
end
