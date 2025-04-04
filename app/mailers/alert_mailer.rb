class AlertMailer < ApplicationMailer
  before_action :set_alert_and_area
  before_action :set_email
  before_action :set_street_address, only: [:reminder, :confirm, :annual_schedule_live]
  before_action :set_formatted_address_area, only: [:confirm]
  before_action :set_disclaimer, only: [:reminder, :confirm, :annual_schedule_live]
  before_action :set_sweep_dates, only: [:reminder]
  before_action :set_mailer_urls, only: [:confirm, :reminder, :annual_schedule_live]

  DISCLAIMER = "Note: This site does not guarantee that the information presented is accurate, or that notifications will be delivered on a timely basis. For for up-to-date parking information, please consult street signage and the websites for the Department of Streets and Sanitation and your local Ward or alderperson."

  def reminder
    mail(
      to: @email,
      subject: "Street sweeping alert for #{@area.name}",
    )
  end

  def confirm
    mail(
      to: @email,
      subject: "Please confirm your subscription to #{@area.name}",
    )
  end

  def annual_schedule_live
    mail(
      to: @email,
      subject: "#{Time.current.year} street sweeping schedule is now live",
    )
  end

  def deleted_notification
    mail(
      to: @email,
      subject: "Your street sweeping alert subscription has been canceled",
    )
  end

  private

  def set_alert_and_area
    @alert = params[:alert]
    @area = @alert.area
  end

  def set_email
    @email = @alert.email
  end

  def set_street_address
    @street_address = @alert.street_address
  end

  def set_formatted_address_area
    @formatted_address_area = @street_address ? "#{@street_address} (#{@area.name})" : @area.name
  end

  def set_disclaimer
    @disclaimer = DISCLAIMER
  end

  def set_sweep_dates
    @sweep = params[:sweep]
    @dates = [
      @sweep.date_1,
      @sweep.date_2,
      @sweep.date_3,
      @sweep.date_4,
    ].compact.map { |d| d.strftime("%B %-d") }
  end

  def set_mailer_urls
    token = encode_jwt(@email, @street_address)
    @confirmation_url = confirm_area_alerts_url(@area, t: token)
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: token)
  end
end
