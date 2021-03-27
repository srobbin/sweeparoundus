class AlertsController < ApplicationController
  include JwtHelper

  before_action :find_area
  before_action :find_alert, only: [:unsubscribe, :confirm]

  def new
    @alert = @area.alerts.new
  end

  def create
    @alert = @area.alerts.find_or_initialize_by(alert_params)

    if @alert.save
      flash.now[:notice] = "Please check your inbox to confirm the subscription."
      AlertMailer.with(alert: @alert).confirm.deliver_later
    else
      flash.now[:alert] = "Invalid email"
    end

    respond_to do |format|
      format.html { redirect_to @area }
      format.turbo_stream
    end
  end

  def unsubscribe
    @alert.try(:destroy)
  end

  def confirm
    @alert.try(:update, { confirmed: true })
  end

  private

  def find_area
    @area = Area.find(params[:area_id])
  end

  def find_alert
    email = decode_jwt(params[:t])["sub"]
    @alert = Alert.find_by(area: @area, email: email)
  end

  def alert_params
    params.permit(:email)
  end
end
