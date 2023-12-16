class AlertsController < ApplicationController
  include JwtHelper

  before_action :find_area
  before_action :find_alert, only: [:unsubscribe, :confirm]

  def new
    @alert = @area.alerts.new
  end

  def create
    email = params[:email].strip.downcase
    @alert = @area.alerts.find_or_initialize_by(email: email, street_address: street_address)

    if @alert.save
      flash.now[:notice] = "Please check your inbox to confirm your subscription. You won't receive alerts at #{email} unless you confirm."
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
    decoded_params = decode_jwt(params[:t])
    email = decoded_params["sub"]
    street_address = decoded_params["street_address"]
    @alert = Alert.find_by(area: @area, email: email, street_address: street_address)
  end

  def street_address
    session[:is_save_street_address_checked] = save_street_address?
    return nil unless save_street_address?  
    session[:street_address]
  end

  def save_street_address?
    params[:is_save_street_address] == "1"
  end
end
