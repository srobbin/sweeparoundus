Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data, "https://*.googleapis.com", "https://*.gstatic.com", "https://www.google-analytics.com", "https://img.buymeacoffee.com"
    policy.object_src  :none
    policy.script_src  :self, "https://maps.googleapis.com", "https://www.googletagmanager.com"
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self, "https://*.googleapis.com", "https://*.google-analytics.com", "https://*.analytics.google.com", "https://*.googletagmanager.com"
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
end
