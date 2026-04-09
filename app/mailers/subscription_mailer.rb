class SubscriptionMailer < ApplicationMailer
  def manage_link
    @email = params[:email]
    @manage_url = manage_subscriptions_url(t: encode_manage_jwt(@email))

    mail(
      to: @email,
      subject: "Manage your #{ENV["SITE_NAME"]} subscriptions",
    )
  end
end
