class AlertsController < ApplicationController
  include JwtHelper
  include SearchContext

  before_action :find_area
  before_action :set_search_context, only: [:create]
  before_action :find_alert, only: [:unsubscribe, :confirm]

  def new
    @alert = @area.alerts.new
  end

  def create
    email = params[:email].strip.downcase
    # Identity for the unique index is (email, street_address); lat/lng
    # are written as attributes only — including them in the lookup makes
    # re-subscribes with slightly different float precision miss the
    # existing row and trip the unique index.
    @alert = @area.alerts.find_or_initialize_by(email: email, street_address: street_address)
    if street_address
      @alert.lat = session[:search_lat]
      @alert.lng = session[:search_lng]
    end

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
    token = params[:t]
    return render_invalid_link unless token.present?

    decoded_params = decode_jwt(token)
    email = decoded_params["sub"]
    address = decoded_params["street_address"]
    @alert = Alert.find_by(area: @area, email: email, street_address: address)
  rescue JWT::DecodeError, JSON::ParserError
    render_invalid_link
  end

  def render_invalid_link
    render "alerts/invalid_link", status: :bad_request
  end

  def street_address
    session[:is_save_street_address_checked] = save_street_address?
    return nil unless save_street_address?  
    session[:street_address]
  end

  def save_street_address?
    return false if search_session_present? && !searched_in_this_area?
    params[:is_save_street_address] == "1"
  end
end
