module ApplicationHelper
  def title
    site_name = ENV["SITE_NAME"]
    site_description = t(:site_description)
    page_title = content_for(:page_title)
    page_title.present? ? "#{page_title} - #{site_name}".html_safe : "#{site_name} - #{site_description}"
  end
end
