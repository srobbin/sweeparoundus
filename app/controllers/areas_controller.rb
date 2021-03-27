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
    
    @area.sweeps.each do |sweep|
      1.upto(4).each do |n|
        date = sweep.send("date_#{n}")
        next unless date.present?

        event = Icalendar::Event.new
        event.summary = "Street Sweeping for #{@area.name}"
        event.uid = "#{date}@sweeparound.us"
        event.url = area_url(@area)
        cal.add_event(event)
      end
    end

    cal.to_ical
  end
end
