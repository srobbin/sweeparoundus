class SendSmsJob < ApplicationJob
  queue_as :sms

  def perform(to:, message:)
    @client = Twilio::REST::Client.new(ENV["TWILIO_ACCOUNT_SID"], ENV["TWILIO_AUTH_TOKEN"])
    @client.messages.create(
      from: ENV["PHONE_NUMBER"],
      to: to,
      body: message,
    )
  end
end
