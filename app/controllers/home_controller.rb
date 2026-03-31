class HomeController < ApplicationController
  before_action :set_note_header
  before_action :set_note

  # Permanent flag to manually control home page note content
  NEW_SCHEDULES_LIVE = false
  # TODO: remove this after the zone dataset is live
  ZONE_DELAY_2026 = true

  def index
  end

  private

  def set_note_header
    @note_header =
      if sweeping_done_for_year?
        "SWEEP YOU NEXT YEAR"
      elsif NEW_SCHEDULES_LIVE
        "#{current_year} SCHEDULES NOW LIVE"
      else
        "#{current_year} SCHEDULES COMING SOON"
      end
  end

  def set_note
    @note = "Please note that alert subscriptions do not carry over from year to year, unless you save your street address when signing up for notifications."
    if NEW_SCHEDULES_LIVE && !is_beginning_of_year?
      @note += " If your street address has changed, simply subscribe with your new address and then unsubscribe the old address via an alert email."
    elsif ZONE_DELAY_2026
      @note += " New schedules will be posted after the City publishes them (typically in late March), at which point all subscriptions that are either unconfirmed or sans street addresses will be deleted." \
        ' <br><br><strong>Update:</strong> The City has <a href="https://data.cityofchicago.org/stories/s/Delayed-Street-Sweeping-Zones-Dataset-3-31-2026/fuz6-n5nj/" target="_blank" rel="noopener noreferrer" class="underline font-medium">announced</a> that the 2026 street sweeping zones dataset is delayed.' \
        ' Please check the <a href="https://www.chicago.gov/city/en/depts/streets/provdrs/streets_san/svcs.html" target="_blank" rel="noopener noreferrer" class="underline font-medium">City of Chicago Streets &amp; Sanitation page</a> for the latest updates.'
    elsif !sweeping_done_for_year? && !NEW_SCHEDULES_LIVE
      @note += " New schedules will be posted after the City publishes them (typically in late March), at which point all subscriptions that are either unconfirmed or sans street addresses will be deleted." \
        ' Check the <a href="https://www.chicago.gov/city/en/depts/streets/provdrs/streets_san/svcs.html" target="_blank" rel="noopener noreferrer" class="underline font-medium">City of Chicago Streets &amp; Sanitation page</a> for the latest updates.'
    end
  end

  def current_year
    Date.today.year
  end

  def sweeping_done_for_year?
    is_month_in?([12])
  end

  def is_beginning_of_year?
    Date.today < Date.new(current_year, 3, 31)
  end

  def is_month_in?(months)
    months.include?(Time.current.month)
  end
end
