ActiveAdmin.register Alert do
  permit_params :area_id, :email, :phone, :confirmed, :street_address
  actions :all, except: [:show]
  config.sort_order = "created_at_desc"

  index do
    column :email
    column :phone
    column :area do |alert|
      link_to alert.area.name, area_url(alert.area), target: "_blank"
    end
    column :street_address do |alert|
      alert.street_address.present? ? alert.street_address[0..-19] : ""
    end
    column :confirmed
    column :updated_at
    actions
  end

  scope :all
  scope :confirmed
  scope :unconfirmed
end
