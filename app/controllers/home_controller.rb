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
      elsif NEW_SCHEDULES_LIVE || !is_beginning_of_year?
        "#{current_year} SCHEDULES NOW LIVE"
      else
        "#{current_year} SCHEDULES COMING SOON"
      end
  end

  def set_note
    @note = "Please note that alert subscriptions do not carry over from year to year, unless you save your street address when signing up for notifications."
    if NEW_SCHEDULES_LIVE && !is_beginning_of_year?
      @note += " If your street address has changed, simply subscribe with your new address and then unsubscribe your old address from an alert email."
    elsif !sweeping_done_for_year? && !NEW_SCHEDULES_LIVE
      @note += " New schedules will be posted after the City publishes them (typically in late March / early April), at which point all subscriptions that are either unconfirmed or sans street addresses will be deleted."
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
