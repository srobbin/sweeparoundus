module ApplicationHelper
  def title
    site_name = ENV["SITE_NAME"]
    site_description = t(:site_description)
    page_title = content_for(:page_title)
    page_title.present? ? "#{page_title} - #{site_name}".html_safe : "#{site_name} - #{site_description}"
  end

  def footer_link_to(label, path, **opts)
    if current_page?(path)
      link_to label, path, class: "font-medium text-gray-900 no-underline", aria: { current: "page" }, **opts
    else
      link_to label, path, class: "underline hover:text-black", **opts
    end
  end
end
