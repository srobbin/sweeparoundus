# Content Security Policy.
#
# Currently in REPORT-ONLY mode: browsers will report violations to the
# /csp-violation-report endpoint but will not block any resources. Once we've
# observed real traffic for a while and confirmed nothing useful is being
# flagged, switch `report_only` to false to start enforcing.
#
# strict-dynamic + nonces is what makes the Google Maps JS API work. Maps loads
# additional scripts dynamically; under strict-dynamic, those inherit trust
# from the nonce on the parent <script> tag.

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self
    policy.font_src    :self, :data
    policy.img_src     :self, :data,
                       "https://*.googleapis.com",
                       "https://*.gstatic.com",
                       "https://www.google-analytics.com",
                       "https://img.buymeacoffee.com"
    policy.object_src  :none
    policy.script_src  :self, :strict_dynamic
    policy.style_src   :self, :unsafe_inline
    policy.connect_src :self,
                       "https://*.googleapis.com",
                       "https://*.google-analytics.com",
                       "https://*.analytics.google.com",
                       "https://*.googletagmanager.com"
    policy.frame_src   :none
    policy.base_uri    :self
    policy.form_action :self
    policy.report_uri  "/csp-violation-report"
  end

  config.content_security_policy_nonce_generator = ->(request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src]
  config.content_security_policy_report_only = true
end
