module JwtHelper
  def encode_jwt(email, street_address)
    payload = { sub: email, street_address: street_address }
    JWT.encode payload, ENV["SECRET_KEY_JWT"], "HS256"
  end

  def decode_jwt(token)
    decoded = JWT.decode(token, ENV["SECRET_KEY_JWT"], true, { algorithm: "HS256" }).first
    raise JWT::DecodeError, "Invalid token purpose" if decoded["purpose"] == "manage"
    decoded
  end

  def encode_manage_jwt(email, expires_in: 1.hour)
    payload = { sub: email, purpose: "manage", exp: expires_in.from_now.to_i }
    JWT.encode payload, ENV["SECRET_KEY_JWT"], "HS256"
  end

  def decode_manage_jwt(token)
    decoded = JWT.decode(token, ENV["SECRET_KEY_JWT"], true, { algorithm: "HS256" }).first
    raise JWT::DecodeError, "Invalid token purpose" unless decoded["purpose"] == "manage"
    raise JWT::DecodeError, "Missing expiration" unless decoded.key?("exp")
    decoded
  end
end
