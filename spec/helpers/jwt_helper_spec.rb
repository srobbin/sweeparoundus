require "rails_helper"

RSpec.describe JwtHelper do
  let(:helper_instance) { Class.new { include JwtHelper }.new }
  let(:email) { "user@example.com" }
  let(:street_address) { "123 Main St" }

  describe "#encode_jwt" do
    it "returns a three-segment JWT string" do
      token = helper_instance.encode_jwt(email, street_address)

      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end
  end

  describe "#decode_jwt" do
    it "round-trips email and street_address" do
      token = helper_instance.encode_jwt(email, street_address)
      decoded = helper_instance.decode_jwt(token)

      expect(decoded["sub"]).to eq(email)
      expect(decoded["street_address"]).to eq(street_address)
    end

    it "handles nil street_address" do
      token = helper_instance.encode_jwt(email, nil)
      decoded = helper_instance.decode_jwt(token)

      expect(decoded["sub"]).to eq(email)
      expect(decoded["street_address"]).to be_nil
    end

    it "raises for a tampered token" do
      token = helper_instance.encode_jwt(email, street_address)

      expect { helper_instance.decode_jwt(token + "x") }.to raise_error(JWT::DecodeError)
    end

    it "raises for a completely invalid token" do
      expect { helper_instance.decode_jwt("not.a.token") }.to raise_error(JWT::DecodeError)
    end

    it "raises for nil" do
      expect { helper_instance.decode_jwt(nil) }.to raise_error(JWT::DecodeError)
    end
  end
end
