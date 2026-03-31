class WardOfficeMailer < ApplicationMailer
  def schedules_live
    @name = params[:name]
    @email = params[:email]
    @ward = params[:ward]

    mail(
      to: @email,
      subject: "Street sweeping reminder resource - #{Time.current.year} schedules live",
    )
  end
end
