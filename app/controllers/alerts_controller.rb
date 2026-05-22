class AlertsController < ApplicationController
  include JwtHelper
  include SearchContext

  before_action :find_area
  before_action :set_search_context, only: [ :create ]
  before_action :find_alert, only: [ :unsubscribe, :confirm ]

  def new
    @alert = @area.alerts.new
  end

  def create
    email = params[:email].strip.downcase

    @alert = build_primary_alert(email)

    if @alert.save
      @neighbor_alerts = create_neighbor_alerts(email)

      AlertMailer.with(alert: @alert, neighbor_alerts: @neighbor_alerts).confirm.deliver_later

      area_count = 1 + @neighbor_alerts.size
      flash.now[:notice] = if area_count > 1
        "Please check your inbox to confirm your #{area_count} subscriptions. You won't receive alerts at #{email} unless you confirm."
      else
        "Please check your inbox to confirm your subscription. You won't receive alerts at #{email} unless you confirm."
      end
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
    if @alert
      @alert.update(confirmed: true)
      confirm_neighbor_alerts
    end
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
    @neighbor_alert_ids = Array(decoded_params["neighbor_alert_ids"])
  rescue JWT::DecodeError, JSON::ParserError
    render_invalid_link
  end

  def render_invalid_link
    render "alerts/invalid_link", status: :bad_request
  end

  def confirm_neighbor_alerts
    return if @neighbor_alert_ids.blank?

    Alert.where(id: @neighbor_alert_ids, email: @alert.email, confirmed: false)
         .update_all(confirmed: true)
  end

  def build_primary_alert(email)
    alert = @area.alerts.find_or_initialize_by(email: email, street_address: street_address)
    if street_address
      alert.lat = session[:search_lat]
      alert.lng = session[:search_lng]
    end
    alert
  end

  def create_neighbor_alerts(email)
    ids = Array(params[:neighbor_area_ids]).compact_blank
    return [] if ids.empty?

    Area.where(id: ids).filter_map do |neighbor_area|
      alert = neighbor_area.alerts.find_or_initialize_by(email: email, street_address: nil)
      if alert.save
        alert
      else
        Rails.logger.warn("[AlertsController] Neighbor alert save failed for area #{neighbor_area.id}: #{alert.errors.full_messages.join(', ')}")
        nil
      end
    end
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
