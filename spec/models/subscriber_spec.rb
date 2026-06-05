require "rails_helper"

RSpec.describe Subscriber do
  describe "validations" do
    it "is valid with a properly formatted email" do
      expect(Subscriber.new(email: "user@example.com")).to be_valid
    end

    it "is invalid without an email" do
      subscriber = Subscriber.new(email: nil)

      expect(subscriber).not_to be_valid
      expect(subscriber.errors[:email]).to be_present
    end

    it "is invalid with a malformed email" do
      subscriber = Subscriber.new(email: "not-an-email")

      expect(subscriber).not_to be_valid
      expect(subscriber.errors[:email]).to be_present
    end

    it "accepts emails with dots and hyphens" do
      expect(Subscriber.new(email: "first.last-name@sub.example.com")).to be_valid
    end

    it "enforces case-insensitive uniqueness" do
      create(:subscriber, email: "dupe@example.com")
      subscriber = Subscriber.new(email: "DUPE@example.com")

      expect(subscriber).not_to be_valid
      expect(subscriber.errors[:email]).to include("has already been taken")
    end
  end

  describe "email normalization" do
    it "strips and downcases the email before validation" do
      subscriber = Subscriber.create!(email: "  User@Example.COM  ")

      expect(subscriber.email).to eq("user@example.com")
    end
  end

  describe "email domain MX validation" do
    it "is valid when the domain has MX records" do
      expect(Subscriber.new(email: "user@gmail.com")).to be_valid
    end

    it "is valid when the domain has no MX but has A records" do
      dns = instance_double(Resolv::DNS)
      allow(Resolv::DNS).to receive(:open).and_yield(dns)
      allow(dns).to receive(:timeouts=)
      allow(dns).to receive(:getresources)
        .with("example.com", Resolv::DNS::Resource::IN::MX)
        .and_return([])
      allow(dns).to receive(:getresources)
        .with("example.com", Resolv::DNS::Resource::IN::A)
        .and_return([ instance_double(Resolv::DNS::Resource::IN::A) ])

      expect(Subscriber.new(email: "user@example.com")).to be_valid
    end

    it "is invalid when the domain has no MX or A records" do
      dns = instance_double(Resolv::DNS)
      allow(Resolv::DNS).to receive(:open).and_yield(dns)
      allow(dns).to receive(:timeouts=)
      allow(dns).to receive(:getresources).and_return([])

      subscriber = Subscriber.new(email: "opera1651@gmail.como")

      expect(subscriber).not_to be_valid
      expect(subscriber.errors[:email]).to include("domain does not appear to accept email")
    end

    it "sets a valid positive timeout on the resolver" do
      dns = Resolv::DNS.new
      allow(Resolv::DNS).to receive(:open).and_yield(dns)
      allow(dns).to receive(:getresources).and_return([])

      expect { Subscriber.new(email: "user@nodns.example").valid? }.not_to raise_error
    end

    it "does not block signups when DNS lookup fails" do
      allow(Resolv::DNS).to receive(:open).and_raise(Resolv::ResolvError)

      expect(Subscriber.new(email: "user@flaky-dns.com")).to be_valid
    end

    it "does not block signups when DNS lookup times out" do
      allow(Resolv::DNS).to receive(:open).and_raise(Resolv::ResolvTimeout)

      expect(Subscriber.new(email: "user@slow-dns.com")).to be_valid
    end

    it "skips MX validation when email format is already invalid" do
      subscriber = Subscriber.new(email: "not-an-email")

      expect(Resolv::DNS).not_to receive(:open)
      subscriber.valid?
      expect(subscriber.errors[:email]).to be_present
    end

    it "only runs the MX check on create" do
      subscriber = create(:subscriber, email: "user@example.com")

      expect(Resolv::DNS).not_to receive(:open)
      expect(subscriber.update(email: "user2@example.com")).to be(true)
    end
  end

  describe "associations" do
    it "destroys dependent alerts when destroyed" do
      area = create(:area)
      subscriber = create(:subscriber)
      create(:alert, subscriber: subscriber, area: area)

      expect { subscriber.destroy }.to change(Alert, :count).by(-1)
    end
  end
end
