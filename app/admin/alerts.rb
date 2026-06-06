ActiveAdmin.register Alert do
  permit_params :area_id, :subscriber_id, :confirmed, :street_address, :permit_notifications
  actions :all, except: [ :show ]
  config.sort_order = "created_at_desc"

  controller do
    def scoped_collection
      super.includes(:area, :subscriber)
    end

    def create
      assign_subscriber_id_from_email
      super
    end

    def update
      assign_subscriber_id_from_email
      super
    end

    private

    # The form's email field is free text (not a <select> of every subscriber),
    # so map it back to a subscriber_id here. An unknown email leaves it nil,
    # letting the `belongs_to :subscriber` validation reject the typo rather than
    # create a junk subscriber — new subscribers are added on the Subscribers
    # screen.
    def assign_subscriber_id_from_email
      return unless params[:alert]

      email = params[:alert].delete(:email).to_s.strip.downcase
      return if email.blank?

      params[:alert][:subscriber_id] = Subscriber.find_by(email: email)&.id
    end
  end

  index do
    column :email do |alert|
      alert.subscriber&.email
    end
    column :area do |alert|
      if alert.area_id
        link_to alert.area.name, area_url(alert.area), target: "_blank"
      end
    end
    column :street_address do |alert|
      alert.street_address && alert.street_address[0..-19]
    end
    column :confirmed
    column :permit_notifications
    column :created_at
    column :updated_at
    actions
  end

  scope :all, default: true
  scope :confirmed
  scope :unconfirmed

  # Email now lives on Subscriber, but Ransack can still search it through the
  # whitelisted `subscriber` association, so `subscriber_email_cont` works here.
  filter :subscriber_email, as: :string, label: "Email"
  filter :area
  filter :confirmed
  filter :permit_notifications
  filter :street_address
  filter :created_at

  form do |f|
    # Build a native datalist for email autocomplete (instead of a <select> of
    # every subscriber). It's attached via the field hint because formtastic
    # renders an html_safe hint verbatim, whereas appending markup to the form
    # directly doesn't survive Arbre rendering. The 1000 cap keeps the payload
    # small; emails beyond it still work since the controller matches any exact
    # email the admin types.
    options = Subscriber.order(:email).limit(1000).pluck(:email).map do |email|
      f.template.content_tag(:option, nil, value: email)
    end
    datalist = f.template.content_tag(:datalist, f.template.safe_join(options), id: "subscriber-emails")

    f.inputs do
      f.input :area
      f.input :email,
        as: :string,
        label: "Email",
        input_html: { list: "subscriber-emails", autocomplete: "off" },
        hint: f.template.safe_join([
          "Type to search existing subscribers. Add new subscribers on the Subscribers screen.",
          datalist
        ])
      f.input :street_address
      f.input :confirmed
      f.input :permit_notifications
    end
    f.actions
  end
end
