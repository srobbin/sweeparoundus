module JwtHelper
  def encode_jwt(email)
    payload = { sub: email }
    JWT.encode payload, ENV["SECRET_KEY_JWT"], "HS256"
  end

  def decode_jwt(token)
    JWT.decode(token, ENV["SECRET_KEY_JWT"], true, { algorithm: "HS256" }).first
  end
end