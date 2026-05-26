class WardOfficeMailer < ApplicationMailer
  def schedules_live
    @name = params[:name]
    @email = params[:email]
    @ward = params[:ward]

    mail(
      to: @email,
      subject: "Free #{Time.current.year} street sweeping reminders for your Ward #{@ward} constituents",
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
