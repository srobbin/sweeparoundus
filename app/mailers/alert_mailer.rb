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
    @street_address = @alert.street_address
    @area = @alert.area
    @dates = [
      @sweep.date_1,
      @sweep.date_2,
      @sweep.date_3,
      @sweep.date_4,
    ].compact.map { |d| d.strftime("%B %-d") }
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: encode_jwt(@alert.email, @street_address))

    mail(
      to: @alert.email,
      subject: "Street sweeping alert for #{@area.name}",
    )
  end

  def confirm
    @alert = params[:alert]
    @area = @alert.area
    @email = @alert.email
    @street_address = @alert.street_address

    token = encode_jwt(@email, @street_address)
    @confirmation_url = confirm_area_alerts_url(@area, t: token)
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: token)

    mail(
      to: @alert.email,
      subject: "Please confirm your subscription to #{@area.name}",
    )
  end
end
