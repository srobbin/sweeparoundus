class AreasController < ApplicationController
  def show
    @area = Area.find(params[:id]).decorate

    respond_to do |format|
      format.html
      format.ics do
        send_data calendar, filename: "SweepAroundUs_#{@area.shortcode}.ics"
      end
    end
  end

  private

  def calendar
    cal = Icalendar::Calendar.new
  
    cal.x_wr_calname = "SweepAround.Us: #{@area.name}"
    cal.x_wr_timezone = "America/Chicago"
    cal.prodid = "-//SweepAround.Us: #{@area.name}//EN"
    cal.calscale = "GREGORIAN"
    
    @area.sweeps.each do |sweep|
      1.upto(4).each do |n|
        date = sweep.object.send("date_#{n}")
        next unless date.present?

        event = Icalendar::Event.new
        event.summary = "Street Sweeping for #{@area.name}"
        event.uid = "#{date}_#{@area.shortcode}-#{}@sweeparound.us"
        event.url = area_url(@area)
        event.dtstamp = date.beginning_of_day
        event.dtstart = Icalendar::Values::Date.new(date)
        event.dtend = Icalendar::Values::Date.new(date + 1.day)

        cal.add_event(event)
      end
    end

    cal.to_ical
  end
end
