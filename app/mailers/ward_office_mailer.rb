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

  def sweeping_data_delayed
    @name = params[:name]
    @email = params[:email]
    @ward = params[:ward]

    mail(
      to: @email,
      subject: "#{Time.current.year} Chicago street sweeping data delayed",
    )
  end
end
