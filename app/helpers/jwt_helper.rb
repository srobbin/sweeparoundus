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

  def encode_manage_jwt(email)
    payload = { sub: email, purpose: "manage", exp: 1.hour.from_now.to_i }
    JWT.encode payload, ENV["SECRET_KEY_JWT"], "HS256"
  end

  def decode_manage_jwt(token)
    decoded = JWT.decode(token, ENV["SECRET_KEY_JWT"], true, { algorithm: "HS256" }).first
    raise JWT::DecodeError, "Invalid token purpose" unless decoded["purpose"] == "manage"
    decoded
  end
end
