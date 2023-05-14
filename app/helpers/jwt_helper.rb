module JwtHelper
  def encode_jwt(email, street_address)
    payload = { sub: email, street_address: street_address }
    JWT.encode payload, ENV["SECRET_KEY_JWT"], "HS256"
  end

  def decode_jwt(token)
    JWT.decode(token, ENV["SECRET_KEY_JWT"], true, { algorithm: "HS256" }).first
  end
end