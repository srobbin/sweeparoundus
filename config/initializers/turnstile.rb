if Rails.env.production?
  required_keys = %w[TURNSTILE_SITE_KEY TURNSTILE_SECRET_KEY]
  missing_keys = required_keys.select { |key| ENV[key].blank? }

  if missing_keys.any?
    raise KeyError, "Missing required Turnstile configuration: #{missing_keys.join(", ")}"
  end
end
