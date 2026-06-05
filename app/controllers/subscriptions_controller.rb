class SubscriptionsController < ApplicationController
  include JwtHelper

  before_action :authenticate_manage_token, only: [ :show, :create, :update, :confirm, :destroy ]
  before_action :set_alerts, only: [ :show ]

  def new
  end

  def send_link
    email = params[:email].to_s.strip.downcase
    if email.match?(Subscriber::VALID_EMAIL_REGEX)
      SubscriptionMailer.with(email: email).manage_link.deliver_later
    end
    redirect_to subscriptions_path, notice: "If you have any subscriptions, you'll receive an email with a link to manage them shortly."
  end

  def show
  end

  def create
    address = params[:address].to_s.strip
    lat = params[:lat]
    lng = params[:lng]

    if address.blank?
      flash.now[:alert] = "Please enter an address."
      return render_manage_with_error
    end

    unless lat.present? && lng.present?
      flash.now[:alert] = "Please select an address from the suggestions."
      return render_manage_with_error
    end

    area = Area.find_by_coordinates(lat, lng)
    unless area
      flash.now[:alert] = "Sorry, we could not find the sweep area associated with your address."
      return render_manage_with_error
    end

    @subscriber ||= find_or_create_subscriber(@email)
    unless @subscriber&.persisted?
      flash.now[:alert] = "Could not create subscription."
      return render_manage_with_error
    end

    @alert = @subscriber.alerts.find_or_initialize_by(street_address: address)
    @alert.assign_attributes(area: area, lat: lat, lng: lng)
    @alert.confirmed = true

    if @alert.save
      set_alerts
      respond_to do |format|
        format.turbo_stream { flash.now[:notice] = "Subscription added for #{@alert.street_address}." }
        format.html { redirect_to manage_subscriptions_path(t: params[:t]), notice: "Subscription added for #{@alert.street_address}." }
      end
    else
      flash.now[:alert] = "Could not create subscription."
      # Don't leave a just-created subscriber orphaned if its first alert failed.
      @subscriber.destroy_if_childless
      render_manage_with_error
    end
  rescue ActiveRecord::RecordNotUnique
    # Subscriber races are handled in find_or_create_subscriber, so this only
    # fires on the alert's unique index — a concurrent request already created
    # this address's subscription.
    redirect_to manage_subscriptions_path(t: params[:t]), notice: "You already have a subscription for this address."
  end

  def update
    @alert = @subscriber&.alerts&.find_by(id: params[:id])

    unless @alert
      return redirect_to manage_subscriptions_path(t: params[:t]), alert: "Subscription not found."
    end

    unless @alert.update(permit_notifications: params[:permit_notifications] == "1")
      return redirect_to manage_subscriptions_path(t: params[:t]), alert: "Could not update subscription."
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to manage_subscriptions_path(t: params[:t]) }
    end
  end

  def confirm
    @alert = @subscriber&.alerts&.find_by(id: params[:id])

    unless @alert&.update(confirmed: true)
      return redirect_to manage_subscriptions_path(t: params[:t]), alert: "Could not confirm subscription."
    end

    set_alerts
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to manage_subscriptions_path(t: params[:t]) }
    end
  end

  def destroy
    @alert = @subscriber&.alerts&.find_by(id: params[:id])

    unless @alert
      return redirect_to manage_subscriptions_path(t: params[:t]), notice: "That subscription could not be found."
    end

    @alert.destroy
    set_alerts

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "Subscription removed." }
      format.html { redirect_to manage_subscriptions_path(t: params[:t]), notice: "Subscription removed." }
    end
  end

  private

  # Resolves (creating on first contact) the subscriber for this manage-page
  # signup. Returns an unpersisted record when the email is invalid (the caller
  # checks `persisted?`), and re-reads on a concurrent-creation race so that
  # subscriber races never surface as the alert-level "already subscribed" flash.
  def find_or_create_subscriber(email)
    Subscriber.find_or_create_by(email: email)
  rescue ActiveRecord::RecordNotUnique
    Subscriber.find_by(email: email)
  end

  def authenticate_manage_token
    decoded = decode_manage_jwt(params[:t])
    @email = decoded["sub"].to_s.strip.downcase
    @subscriber = Subscriber.find_by(email: @email)
    @token = params[:t]
  rescue JWT::ExpiredSignature
    redirect_to subscriptions_path, alert: "Your link has expired. Please request a new one."
  rescue JWT::DecodeError
    redirect_to subscriptions_path, alert: "Invalid link. Please request a new one."
  end

  def set_alerts
    @alerts = @subscriber&.alerts&.includes(area: :sweeps)&.order(:created_at) || Alert.none
    @pending_alerts, @active_alerts = @alerts.partition { |a| !a.confirmed? }
  end

  def render_manage_with_error
    set_alerts
    render :show, status: :unprocessable_content
  end
end
