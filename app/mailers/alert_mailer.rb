class AlertMailer < ApplicationMailer
  before_action :set_alert_and_area
  before_action :set_email
  before_action :set_street_address, only: [ :reminder, :confirm, :annual_schedule_live, :sweeping_data_delayed ]
  before_action :set_formatted_address_area, only: [ :confirm ]
  before_action :set_sweep_dates, only: [ :reminder ]
  before_action :set_annual_first_sweep, only: [ :annual_schedule_live ]
  before_action :set_mailer_urls, only: [ :confirm, :reminder, :annual_schedule_live, :sweeping_data_delayed ]
  before_action :set_manage_url, only: [ :reminder, :annual_schedule_live, :sweeping_data_delayed ]
  before_action :set_static_map_url, only: [ :reminder, :confirm ]

  def reminder
    mail(
      to: @email,
      subject: reminder_subject,
    )
  end

  def confirm
    mail(to: @email, subject: confirm_subject)
  end

  def annual_schedule_live
    mail(
      to: @email,
      subject: "Your #{Time.current.year} sweep dates are ready—check your schedule",
    )
  end

  def sweeping_data_delayed
    mail(
      to: @email,
      subject: "#{Time.current.year} Chicago street sweeping alerts are delayed",
    )
  end

  def deleted_notification
    mail(
      to: @email,
      subject: "Your #{ENV["SITE_NAME"]} subscription for #{@area.name} was canceled—here's why",
    )
  end

  private

  def set_alert_and_area
    @alert = params[:alert]
    @area = @alert.area
    @neighbor_alerts = Array(params[:neighbor_alerts])
    @neighbor_areas = @neighbor_alerts.map(&:area)
  end

  def set_email
    @email = @alert.email
  end

  def set_street_address
    @raw_street_address = @alert.street_address
    @street_address = @raw_street_address&.sub(/,\s*Chicago,\s*IL,\s*USA\s*\z/i, "")
  end

  def set_formatted_address_area
    @formatted_address_area = @street_address ? "#{@street_address} (#{@area.name})" : @area.name
  end

  def set_sweep_dates
    @sweep = params[:sweep]
    @dates = format_sweep_dates(@sweep)
  end

  # The annual_schedule_live email surfaces the first sweep of the new
  # season near the top, so subscribers immediately see when the year
  # "starts" for their address. Area#sweeps is already scoped to the
  # current year and ordered by date_1, so .first is "the first sweep
  # of the new season". Returns [] when there are no sweeps yet, which
  # the view uses to render carry-over copy instead.
  def set_annual_first_sweep
    @first_sweep_dates = format_sweep_dates(@area.sweeps.first)
  end

  def format_sweep_dates(sweep)
    return [] unless sweep

    [ sweep.date_1, sweep.date_2, sweep.date_3, sweep.date_4 ]
      .compact
      .map { |d| d.strftime("%a, %b %-d") }
  end

  def set_mailer_urls
    neighbor_ids = @neighbor_alerts.map { |a| a.id.to_s }.presence
    token = encode_jwt(@email, @raw_street_address, neighbor_alert_ids: neighbor_ids)
    @confirmation_url = confirm_area_alerts_url(@area, t: token)
    @unsubscribe_url = unsubscribe_area_alerts_url(@area, t: token)
  end

  def set_manage_url
    @manage_url = manage_subscriptions_url(t: encode_manage_jwt(@email, expires_in: 60.days))
  end

  def set_static_map_url
    @static_map_url = AlertStaticMap.new(alert: @alert, area: @area).url
  end

  def reminder_subject
    if @street_address.present?
      "Tomorrow: Street sweeping at #{@street_address}"
    else
      "Tomorrow: Street sweeping in #{@area.name}"
    end
  end

  def confirm_subject
    if @neighbor_areas.any?
      "Confirm your #{1 + @neighbor_areas.size} #{ENV["SITE_NAME"]} subscriptions"
    elsif @street_address.present?
      "Confirm your #{ENV["SITE_NAME"]} alerts for #{@street_address}"
    else
      "Confirm your #{ENV["SITE_NAME"]} alerts for #{@area.name}"
    end
  end
end
