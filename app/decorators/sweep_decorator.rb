class SweepDecorator < ApplicationDecorator
  def date_1
    formatted_date(object.date_1)
  end

  def date_2
    formatted_date(object.date_2)
  end

  def date_3
    formatted_date(object.date_3)
  end

  def date_4
    formatted_date(object.date_4)
  end

  private

  def formatted_date(date)
    date.present? ? date.strftime("%b %-d") : "—"
  end
end
