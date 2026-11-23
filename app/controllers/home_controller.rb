class HomeController < ApplicationController
  before_action :force_html_format
  before_action :set_note_header
  before_action :set_note

  # Permanent flag to manually control home page note content
  NEW_SCHEDULES_LIVE = true

  # Temporary 2026 late-season extension (Sun-Times, Nov 19 2026):
  # City is posting sweeping signs through Dec 17, but the 2026 open-data
  # schedule that powers this site will NOT be updated — extra sweeps are
  # ad hoc based on weather/capacity. Auto-expires after Dec 17, 2026.
  EXTENDED_SWEEPING_START = Date.new(2026, 11, 19)
  EXTENDED_SWEEPING_END = Date.new(2026, 12, 17)

  def index
  end

  private

  # Bots and feed readers sometimes request "/" with a non-HTML format
  # (e.g. .ics), which would otherwise raise UnknownFormat -> 406 and create
  # Sentry log noise. The home page only has an HTML representation, so always
  # render it.
  def force_html_format
    request.format = :html
  end

  def set_note_header
    @note_header =
      if extended_sweeping_period?
        "#{current_year} SWEEPING EXTENDED THROUGH DEC 17"
      elsif sweeping_done_for_year?
        "SWEEP YOU NEXT YEAR"
      elsif NEW_SCHEDULES_LIVE
        "#{current_year} SCHEDULES NOW LIVE"
      else
        "#{current_year} SCHEDULES COMING SOON"
      end
  end

  def set_note
    @note = "Please note that email subscriptions don't carry over from year to year, unless you save your street address when signing up."
    if NEW_SCHEDULES_LIVE && !is_beginning_of_year?
      @note += ' If your address has changed, please visit the <a href="/subscriptions" class="underline font-medium">Manage Subscriptions</a> page.'
    # elsif ZONE_DELAY_2026
    #   @note += " New schedules will be posted after the City publishes them (typically in late March), at which point all subscriptions that are either unconfirmed or sans street addresses will be deleted." \
    #     ' <br><br><strong>Update:</strong> The City has <a href="https://data.cityofchicago.org/stories/s/Delayed-Street-Sweeping-Zones-Dataset-3-31-2026/fuz6-n5nj/" target="_blank" rel="noopener noreferrer" class="underline font-medium">announced</a> that the 2026 street sweeping zones dataset is delayed.' \
    #     ' Please check the <a href="https://www.chicago.gov/city/en/depts/streets/provdrs/streets_san/svcs.html" target="_blank" rel="noopener noreferrer" class="underline font-medium">City of Chicago Streets &amp; Sanitation page</a> for the latest updates.'
    elsif !sweeping_done_for_year? && !NEW_SCHEDULES_LIVE
      @note += " New schedules will be posted after the City publishes them (typically in late March), at which point all subscriptions that are either unconfirmed or sans street addresses will be deleted." \
        ' Check the <a href="https://www.chicago.gov/city/en/depts/streets/provdrs/streets_san/svcs.html" target="_blank" rel="noopener noreferrer" class="underline font-medium">City of Chicago Streets &amp; Sanitation page</a> for the latest updates.'
    end
    if extended_sweeping_period?
      @note += ' <br><br><strong>Extended season through Dec. 17:</strong> The City has extended street sweeping through Dec. 17—about a month past its usual Thanksgiving cutoff—to catch lingering leaves.' \
        ' Extra sweeps will be scheduled ad hoc based on weather and crew capacity, and the City\'s <a href="https://data.cityofchicago.org/Sanitation/Street-Sweeping-Schedule-2026/u5ai-3efk/about_data" target="_blank" rel="noopener noreferrer" class="underline font-medium">2026 schedule data</a> that powers We The Sweeple will not be updated, so schedules and email alerts here will miss them.' \
        ' Please watch for temporary orange signs on your block. (<a href="https://chicago.suntimes.com/news/2026/11/19/chicago-extends-street-sweeping-to-week-before-christmas-as-leaves-linger-on-city-trees" target="_blank" rel="noopener noreferrer" class="underline font-medium">Sun-Times, Nov. 19</a>)'
    end
  end

  def current_year
    Date.today.year
  end

  def sweeping_done_for_year?
    is_month_in?([ 12 ]) && !extended_sweeping_period?
  end

  def extended_sweeping_period?
    EXTENDED_SWEEPING_START <= Date.current && Date.current <= EXTENDED_SWEEPING_END
  end

  def is_beginning_of_year?
    Date.today < Date.new(current_year, 3, 31)
  end

  def is_month_in?(months)
    months.include?(Time.current.month)
  end
end
