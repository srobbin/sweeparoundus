class WebhooksController < ApplicationController
  skip_before_action :verify_authenticity_token
  before_action :verify_sid

  def twilio_sms
    @from = params["From"]
    @body = params["Body"].upcase.strip
    @shortcode = @body.match(/W\d+A\d+/)
    @area = Area.find_by(shortcode: @shortcode[0]) if @shortcode
    
    # STOP
    if @body.include?("STOP") && @area.present?
      alert = Alert.find_by(phone: @from, area: @area)
      alert.try(:destroy)
      send_message "This phone number is now unsubscribed street sweeping alerts for #{@area.name}. #{area_url(@area)}"
      return
    end

    # STOP ALL
    if @body.include?("STOP")
      Alert.find_by(phone: @from).destroy_all
      send_message "This phone number is now unsubscribed from all text message street sweeping alerts. #{ENV["SITE_URL"]}"
      return
    end

    # SUBSCRIBE
    if @area.present?
      Alert.find_or_create_by(phone: @from, area: @area, confirmed: true)
      send_message "This phone number is now subscribed to alerts for #{@area.name}. #{area_url(@area)}"
      return
    end

    # FALLBACK
    send_message "Sorry, we didn't understand your text message. #{ENV["SITE_URL"]}"

    # Response
    head :ok
  end

  def twilio_voice
    response = Twilio::TwiML::VoiceResponse.new do |r|
      r.say(message: "I am sorry. Sweep Around Us does not accept phone calls. Please visit our website.")
    end

    render plain: response.to_s
  end

  private

  def verify_sid
    return if params["AccountSid"] == ENV["TWILIO_ACCOUNT_SID"]
    head :unauthorized
  end

  def send_message(message)
    SendSmsJob.perform_later(to: @from, message: "[SweepAround.Us] #{message}")
  end
end
