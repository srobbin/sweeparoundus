class AlertMailer < ApplicationMailer
  def yearly
    mail(
      to: params[:email],
      subject: "2022 street sweeping schedule is now live",
    )
  end

  def reminder
    @sweep = params[:sweep]
    @alert = params[:alert]
    @area = @alert.area
    @dates = [
      @sweep.date_1,
      @sweep.date_2,
      @sweep.date_3,
      @sweep.date_4,
    ].compact.map { |d| d.strftime("%B %-d") }
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: token)

    set_unsubscribe_headers

    mail(
      to: @alert.email,
      subject: "Street sweeping alert for #{@area.name}",
    )
  end

  def confirm
    @alert = params[:alert]
    @area = @alert.area
    @email = @alert.email
    @confirmation_url = confirm_area_alerts_url(@area, t: token)
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: token)

    set_unsubscribe_headers

    mail(
      to: @alert.email,
      subject: "Please confirm your subscription to #{@area.name}",
    )
  end

  private

  def token
    @token ||= encode_jwt(@alert.email)
  end

  def set_unsubscribe_headers
    headers({
      "List-Unsubscribe-Post" => "List-Unsubscribe=One-Click",
      "List-Unsubscribe" => "<#{unsubscribe_all_url(token: token)}>",
    })
  end
end
