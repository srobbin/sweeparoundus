class ApplicationMailer < ActionMailer::Base
  include JwtHelper

  default from: "#{ENV["SITE_NAME"]} <#{ENV["DEFAULT_EMAIL"]}>"
  layout "mailer"
end
