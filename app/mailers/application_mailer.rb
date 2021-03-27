class ApplicationMailer < ActionMailer::Base
  include JwtHelper

  default from: "#{I18n.t(:site_name)} <#{ENV["DEFAULT_EMAIL"]}>"
  layout "mailer"
end
