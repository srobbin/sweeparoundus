class AreasController < ApplicationController
  include SearchContext

  before_action :find_area, only: :show
  before_action :set_search_context, only: :show, if: -> { request.format.html? }
  before_action :load_neighbors, only: :show, if: -> { request.format.html? }

  def show
    respond_to do |format|
      format.html
      format.ics do
        send_data calendar, filename: "#{ENV["SITE_NAME"].gsub(" ", "")}_#{@area.shortcode}.ics"
      end
    end
  end

  private

  def find_area
    @area = Area.find(params[:id]).decorate
  end

  def calendar
    cal = Icalendar::Calendar.new
  
    cal.x_wr_calname = "#{ENV["SITE_NAME"]}: #{@area.name}"
    cal.x_wr_timezone = "America/Chicago"
    cal.prodid = "-//#{ENV["SITE_NAME"]}: #{@area.name}//EN"
    cal.calscale = "GREGORIAN"
    
    @area.sweeps.each do |sweep|
      1.upto(4).each do |n|
        date = sweep.object.send("date_#{n}")
        next unless date.present?

        event = Icalendar::Event.new
        event.summary = "Street Sweeping for #{@area.name}"
        event.uid = "#{date}_#{@area.shortcode}@#{URI.parse(ENV["SITE_URL"]).host}"
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
