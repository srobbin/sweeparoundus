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
    @street_address = @alert.street_address
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
    @formatted_address_area = formatted_address_area(@street_address, @area)

    token = encode_jwt(@email, @street_address)
    @confirmation_url = confirm_area_alerts_url(@area, t: token)
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: token)

    mail(
      to: @alert.email,
      subject: "Please confirm your subscription to #{@area.name}",
    )
  end

  def deleted_notification
    @alert = params[:alert]
    @area = @alert.area
    @home_url = root_url

    mail(
      to: @alert.email,
      subject: "Your street sweeping alert subscription has been canceled",
    )
  end

  private

  def formatted_address_area(street_address, area)
    if street_address
      "#{street_address} (#{area.name})"
    else
      area.name
    end
  end
end
