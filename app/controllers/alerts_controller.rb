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
    email = params[:email].to_s.strip.downcase
    subscriber = find_or_create_subscriber(email)

    unless subscriber
      flash.now[:alert] = "Invalid email"
      return respond_to do |format|
        format.html { redirect_to @area }
        format.turbo_stream
      end
    end

    @alert = build_primary_alert(subscriber)

    if @alert.save
      @neighbor_alerts = create_neighbor_alerts(subscriber)

      AlertMailer.with(alert: @alert, neighbor_alerts: @neighbor_alerts).confirm.deliver_later

      area_count = 1 + @neighbor_alerts.size
      flash.now[:notice] = if area_count > 1
        "Check your inbox to confirm your #{area_count} subscriptions. You won't receive alerts at #{email} unless you confirm."
      else
        "Check your inbox to confirm your subscription. You won't receive alerts at #{email} unless you confirm."
      end
    else
      flash.now[:alert] = "Something went wrong creating your subscription. Please try again."
      subscriber.destroy_if_childless
      Sentry.set_context("create_alert", {
        area_id: @area.id,
        subscriber_id: subscriber.id,
        errors: @alert.errors.full_messages
      })
      Sentry.capture_message("Primary alert save failed", level: :warning)
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
    return unless @alert

    unless @alert.update(confirmed: true)
      Sentry.set_context("confirm_alert", {
        alert_id: @alert.id,
        area_id: @area.id,
        errors: @alert.errors.full_messages
      })
      Sentry.capture_message("Alert confirmation update failed", level: :warning)
      return
    end

    confirm_neighbor_alerts
  end

  private

  def find_area
    @area = Area.find(params[:area_id])
  end

  def find_alert
    token = params[:t]
    # A blank token means the request didn't come from a real email link
    # (those always carry ?t=<jwt>); it's almost always a bot or link scanner
    # hitting the bare URL. Render the invalid-link page with a 200 so Rails
    # doesn't log it as a 400 warning and create Sentry noise.
    return render_invalid_link(status: :ok) unless token.present?

    decoded_params = decode_jwt(token)
    email = decoded_params["sub"]
    address = decoded_params["street_address"]
    @alert = lookup_alert(email, address)
    # The link's area_id (from the URL) can be stale if regeocoding or the
    # annual carry-over moved the alert to a new area after the email was sent.
    # Resync @area to the alert's current area so downstream code is correct.
    @area = @alert.area if @alert
    @neighbor_alert_ids = Array(decoded_params["neighbor_alert_ids"])

    report_missing_alert(email, address) unless @alert
  rescue JWT::DecodeError, JSON::ParserError
    render_invalid_link
  end

  # (subscriber_id, street_address) is globally unique (see Alert validations),
  # so for address-bearing alerts we ignore the (possibly stale) URL area.
  # Address-less alerts are only unique per area, so those stay scoped
  # to @area. The email may come from a legacy JWT, so normalize before lookup.
  def lookup_alert(email, address)
    subscriber = Subscriber.find_by(email: email.to_s.strip.downcase)
    return nil unless subscriber

    if address.present?
      subscriber.alerts.find_by(street_address: address)
    else
      subscriber.alerts.find_by(area: @area, street_address: nil)
    end
  end

  def report_missing_alert(email, address)
    # A missing alert on unsubscribe is expected and benign (double-clicks,
    # already-unsubscribed links, alerts removed by cleanup), so don't alert.
    return if params[:action] == "unsubscribe"

    Sentry.set_context("find_alert", {
      area_id: @area.id,
      email: email,
      jwt_street_address: address,
      action: params[:action]
    })
    Sentry.capture_message("Valid JWT but alert not found", level: :warning)
  end

  def render_invalid_link(status: :bad_request)
    render "alerts/invalid_link", status: status
  end

  def confirm_neighbor_alerts
    return if @neighbor_alert_ids.blank?

    neighbors = Alert.where(id: @neighbor_alert_ids, subscriber_id: @alert.subscriber_id)

    if neighbors.none?
      Sentry.set_context("confirm_neighbor_alerts", {
        alert_id: @alert.id,
        neighbor_alert_ids: @neighbor_alert_ids
      })
      Sentry.capture_message("Neighbor alert IDs from JWT not found", level: :warning)
      return
    end

    pending_count = neighbors.where(confirmed: false).count
    updated_count = neighbors.where(confirmed: false).update_all(confirmed: true)

    return unless pending_count.positive? && updated_count.zero?

    Sentry.set_context("confirm_neighbor_alerts", {
      alert_id: @alert.id,
      neighbor_alert_ids: @neighbor_alert_ids,
      pending_count: pending_count
    })
    Sentry.capture_message("Failed to confirm neighbor alerts", level: :warning)
  end

  def find_or_create_subscriber(email)
    Subscriber.find_or_create_by!(email: email)
  rescue ActiveRecord::RecordInvalid
    nil
  rescue ActiveRecord::RecordNotUnique
    # Concurrent first-time signups race on the unique index; the loser re-reads.
    Subscriber.find_by(email: email)
  end

  def build_primary_alert(subscriber)
    alert = @area.alerts.find_or_initialize_by(subscriber: subscriber, street_address: street_address)
    if street_address
      alert.lat = session[:search_lat]
      alert.lng = session[:search_lng]
    end
    alert
  end

  def create_neighbor_alerts(subscriber)
    ids = Array(params[:neighbor_area_ids]).compact_blank
    return [] if ids.empty?

    Area.where(id: ids).filter_map do |neighbor_area|
      find_or_create_neighbor_alert(neighbor_area, subscriber)
    end
  end

  def find_or_create_neighbor_alert(neighbor_area, subscriber)
    existing = neighbor_area.alerts.find_by(subscriber: subscriber)
    return existing if existing

    alert = neighbor_area.alerts.new(subscriber: subscriber, street_address: nil)
    return alert if alert.save

    # Concurrent requests can both pass find_by and race on insert.
    existing = neighbor_area.alerts.find_by(subscriber: subscriber)
    return existing if existing

    Rails.logger.warn("[AlertsController] Neighbor alert save failed for area #{neighbor_area.id}: #{alert.errors.full_messages.join(', ')}")
    nil
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
