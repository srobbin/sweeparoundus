class ApplicationMailer < ActionMailer::Base
  include JwtHelper

  rescue_from StandardError do |exception|
    Sentry.set_context("mailer", {
      mailer: self.class.name,
      action: action_name,
      to: message.to,
      params: params&.transform_values { |v| v.try(:id) || v.class.name },
    })
    Sentry.capture_exception(exception)
    raise
  end

  # Standard small-print disclaimer surfaced at the bottom of any user-facing
  # email that informs subscribers about parking/sweeping/permit data. Lives
  # on the base mailer so the shared footer partial can read it directly
  # without each subclass having to plumb it through.
  DISCLAIMER = "Note: This site does not guarantee that the information presented is accurate, or that notifications will be delivered on a timely basis. For up-to-date parking information, please consult street signage and the Department of Streets and Sanitation website."

  default from: "#{ENV["SITE_NAME"]} <#{ENV["DEFAULT_EMAIL"]}>"
  layout "mailer"
end
