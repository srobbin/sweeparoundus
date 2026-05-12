class PermitMailer < ApplicationMailer
  TIME_ZONE = "America/Chicago".freeze

  # Precomputed per-permit data for templates (keeps views declarative).
  Match = Struct.new(
    :permit,
    :distance_feet,
    :segment_label,
    :permit_dates,
    :work_type_description,
    :application_description,
    :static_map_url,
    keyword_init: true,
  )

  def notify
    @alert = params[:alert]
    @email = @alert.email
    @street_address = @alert.street_address

    @matches = Array(params[:matches]).map { |m| build_match(m) }

    @manage_url = manage_subscriptions_url(t: encode_manage_jwt(@email, expires_in: 60.days))

    mail(to: @email, subject: subject_line)
  end

  private

  def build_match(attrs)
    permit = attrs[:permit]
    Match.new(
      permit: permit,
      distance_feet: attrs[:distance_feet],
      segment_label: permit.segment_label,
      permit_dates: format_permit_dates(permit),
      work_type_description: permit.work_type_description,
      application_description: permit.application_description,
      static_map_url: PermitStaticMap.new(
        alert: @alert,
        line_from: attrs[:line_from],
        line_to: attrs[:line_to],
      ).url,
    )
  end

  def format_permit_dates(permit)
    start_at = permit.application_start_date&.in_time_zone(TIME_ZONE)
    end_at   = permit.application_end_date&.in_time_zone(TIME_ZONE)

    if start_at && end_at && start_at.to_date != end_at.to_date
      "#{format_date(start_at)} – #{format_date(end_at)}"
    elsif start_at
      format_date(start_at)
    end
  end

  def format_date(time)
    time.strftime("%A, %B %-d")
  end

  # Lists affected street names; falls back to the subscriber's address
  # if no permit has a usable street name.
  def subject_line
    streets = @matches.map { |m| m.permit.display_street }.compact.uniq
    if streets.empty?
      "Temporary No Parking near #{@street_address}"
    else
      "Temporary No Parking on #{streets.join(', ')}"
    end
  end
end
