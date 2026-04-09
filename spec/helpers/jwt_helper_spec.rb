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

    it "raises for a manage token" do
      token = helper_instance.encode_manage_jwt(email)

      expect { helper_instance.decode_jwt(token) }.to raise_error(JWT::DecodeError, "Invalid token purpose")
    end
  end

  describe "#encode_manage_jwt" do
    it "returns a three-segment JWT string" do
      token = helper_instance.encode_manage_jwt(email)

      expect(token).to be_a(String)
      expect(token.split(".").length).to eq(3)
    end

    it "includes purpose and expiration in the payload" do
      token = helper_instance.encode_manage_jwt(email)
      decoded = JWT.decode(token, ENV["SECRET_KEY_JWT"], true, { algorithm: "HS256" }).first

      expect(decoded["sub"]).to eq(email)
      expect(decoded["purpose"]).to eq("manage")
      expect(decoded["exp"]).to be_a(Integer)
    end
  end

  describe "#decode_manage_jwt" do
    it "round-trips email" do
      token = helper_instance.encode_manage_jwt(email)
      decoded = helper_instance.decode_manage_jwt(token)

      expect(decoded["sub"]).to eq(email)
      expect(decoded["purpose"]).to eq("manage")
    end

    it "raises for a non-manage token" do
      token = helper_instance.encode_jwt(email, street_address)

      expect { helper_instance.decode_manage_jwt(token) }.to raise_error(JWT::DecodeError, "Invalid token purpose")
    end

    it "raises for an expired token" do
      payload = { sub: email, purpose: "manage", exp: 1.hour.ago.to_i }
      token = JWT.encode(payload, ENV["SECRET_KEY_JWT"], "HS256")

      expect { helper_instance.decode_manage_jwt(token) }.to raise_error(JWT::ExpiredSignature)
    end

    it "raises for a tampered token" do
      token = helper_instance.encode_manage_jwt(email)

      expect { helper_instance.decode_manage_jwt(token + "x") }.to raise_error(JWT::DecodeError)
    end

    it "raises for nil" do
      expect { helper_instance.decode_manage_jwt(nil) }.to raise_error(JWT::DecodeError)
    end
  end
end
