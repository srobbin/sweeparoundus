ActiveAdmin.register Subscriber do
  permit_params :email
  config.sort_order = "created_at_desc"

  controller do
    def scoped_collection
      super.left_joins(:alerts)
           .select("subscribers.*, COUNT(alerts.id) AS alerts_count")
           .group("subscribers.id")
    end
  end

  scope :all, default: true

  index do
    column :email
    column("Alerts", sortable: "alerts_count") { |subscriber| subscriber.alerts_count }
    column :created_at
    column :updated_at
    actions
  end

  filter :email
  filter :created_at

  show do
    attributes_table do
      row :email
      row :created_at
      row :updated_at
    end

    panel "Alerts" do
      table_for subscriber.alerts.includes(:area).order(:created_at) do
        column :area do |alert|
          link_to(alert.area.name, area_url(alert.area), target: "_blank") if alert.area_id
        end
        column :street_address
        column :confirmed
        column :permit_notifications
        column :created_at
      end
    end
  end

  form do |f|
    f.inputs do
      f.input :email
    end
    f.actions
  end
end
