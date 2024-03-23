class HomeController < ApplicationController
  before_action :set_note_header
  before_action :set_note

  NEW_SCHEDULES_LIVE = false

  def index
  end

  private

  def set_note_header
    @note_header =
      if sweeping_done_for_year?
        "SWEEP YOU NEXT YEAR"
      elsif NEW_SCHEDULES_LIVE && !is_january_thru_march?
        "#{current_year} SCHEDULES NOW LIVE"
      else
        "#{current_year} SCHEDULES COMING SOON"
      end
  end

  def set_note
    @note = "Please note that alert subscriptions do not carry over from year to year, unless you save your street address when signing up for notifications."
    if NEW_SCHEDULES_LIVE && !is_january_thru_march?
      @note += " If your street address has changed, simply subscribe with your new address and then unsubscribe your old address from an alert email."
    elsif !sweeping_done_for_year? && !NEW_SCHEDULES_LIVE
      @note += " New schedules will be posted after the City publishes them (typically in late March or early April), at which point all alert subscriptions that are either unconfirmed or without street addresses will be deleted."
    end
  end

  def current_year
    Date.today.year
  end

  def sweeping_done_for_year?
    is_month_in?([12])
  end

  def is_january_thru_march?
    is_month_in?([1, 2, 3])
  end

  def is_month_in?(months)
    months.include?(Time.current.month)
  end
end
