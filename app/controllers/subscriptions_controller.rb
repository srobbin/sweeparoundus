class SubscriptionsController < ApplicationController
  include JwtHelper

  before_action :authenticate_manage_token, only: [:show, :create, :confirm, :destroy]
  before_action :set_alerts, only: [:show]

  def new
  end

  def send_link
    email = params[:email].to_s.strip.downcase
    if email.match?(Alert::VALID_EMAIL_REGEX)
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

    @alert = Alert.find_or_initialize_by(
      email: @email,
      street_address: address
    )
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
      render_manage_with_error
    end
  rescue ActiveRecord::RecordNotUnique
    redirect_to manage_subscriptions_path(t: params[:t]), notice: "You already have a subscription for this address."
  end

  def confirm
    @alert = Alert.find_by(id: params[:id], email: @email)

    unless @alert&.update(confirmed: true)
      return redirect_to manage_subscriptions_path(t: params[:t]), alert: "Could not confirm subscription."
    end

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to manage_subscriptions_path(t: params[:t]) }
    end
  end

  def destroy
    @alert = Alert.find_by(id: params[:id], email: @email)

    unless @alert
      return redirect_to manage_subscriptions_path(t: params[:t]), notice: "That subscription could not be found."
    end

    @alert.destroy
    @remaining_count = Alert.where(email: @email).count

    respond_to do |format|
      format.turbo_stream { flash.now[:notice] = "Subscription removed." }
      format.html { redirect_to manage_subscriptions_path(t: params[:t]), notice: "Subscription removed." }
    end
  end

  private

  def authenticate_manage_token
    decoded = decode_manage_jwt(params[:t])
    @email = decoded["sub"]
    @token = params[:t]
  rescue JWT::ExpiredSignature
    redirect_to subscriptions_path, alert: "Your link has expired. Please request a new one."
  rescue JWT::DecodeError
    redirect_to subscriptions_path, alert: "Invalid link. Please request a new one."
  end

  def set_alerts
    @alerts = Alert.where(email: @email).includes(:area).order(:created_at)
  end

  def render_manage_with_error
    set_alerts
    render :show, status: :unprocessable_entity
  end
end
