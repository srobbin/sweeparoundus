# Content Security Policy.
#
# Enforced: browsers block violations and POST reports to
# /csp-violation-report.
#
# strict-dynamic + nonces let Google Maps load child scripts that inherit trust
# from the nonced parent <script> tag.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data,
                       "https://fonts.gstatic.com",
                       "http://fonts.gstatic.com"
    # The Google Maps web component renders suggestion/icon images from blob: URLs.
    policy.img_src     :self, :data, :blob,
                       "https://*.googleapis.com",
                       "https://*.gstatic.com",
                       "https://www.google-analytics.com",
                       "https://*.googletagmanager.com",
                       "https://img.buymeacoffee.com"
    policy.object_src  :none
    # Fallback for browsers that ignore 'strict-dynamic': allow https: so
    # Google's dynamically injected child scripts can still load.
    policy.script_src  :self, :strict_dynamic, :https
    policy.style_src   :self, :unsafe_inline,
                       "https://fonts.googleapis.com"
    policy.connect_src :self,
                       "https://*.googleapis.com",
                       "https://*.google-analytics.com",
                       "https://*.analytics.google.com",
                       "https://*.googletagmanager.com",
                       "https://www.google.com"
    policy.frame_src   Rails.env.development? ? :self : :none
    policy.base_uri    :self
    policy.form_action :self
    policy.report_uri  "/csp-violation-report"
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = false
end

# Active Admin's Sprockets + Arbre scripts don't get CSP nonces. Admin pages
# are authenticated, so fall back to 'self' + 'unsafe-inline' there.
# Devise login/password controllers need the same policy because they inherit
# from DeviseController, not BaseController.
Rails.application.config.after_initialize do
  relaxed_script_src = ->(policy) { policy.script_src :self, :unsafe_inline }

  ActiveAdmin::BaseController.content_security_policy(&relaxed_script_src)
  ActiveAdmin::Devise::SessionsController.content_security_policy(&relaxed_script_src)
  ActiveAdmin::Devise::PasswordsController.content_security_policy(&relaxed_script_src)
end
