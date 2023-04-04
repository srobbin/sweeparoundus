class AlertsController < ApplicationController
  include JwtHelper

  before_action :find_area, except: [:unsubscribe_all]
  before_action :find_alert, only: [:unsubscribe, :confirm]

  def new
    @alert = @area.alerts.new
  end

  def create
    email = params[:email].strip
    @alert = @area.alerts.where("LOWER(email) = ?", email.downcase).first_or_initialize(email: email)

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

  def unsubscribe_all
    email = decode_jwt(params[:token])["sub"]
    Alert.where(email: email).destroy_all

    head :ok
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
end
