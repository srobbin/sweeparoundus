ActiveAdmin.register CdotPermit do
  actions :all, except: [ :new, :create, :destroy ]
  config.sort_order = "application_start_date_desc"

  permit_params :application_status, :application_start_date, :application_end_date,
                :application_expire_date, :detail, :parking_meter_posting_or_bagging,
                :street_number_from, :street_number_to, :direction, :street_name, :suffix,
                :placement, :street_closure, :ward

  index do
    selectable_column
    column :unique_key
    column :application_name
    column :application_status
    column :work_type_description
    column :segment_label
    column :ward
    column :placement
    column :street_closure
    column :application_start_date
    column :application_expire_date
    column :processed_alert_ids
    column :notifications_sent_at
    actions
  end

  filter :unique_key
  filter :application_number
  filter :application_name
  filter :application_status, as: :select
  filter :application_type, as: :select
  filter :work_type, as: :select
  filter :work_type_description, as: :select
  filter :street_name
  filter :ward
  filter :parking_meter_posting_or_bagging, as: :select
  filter :street_closure, as: :select
  filter :application_start_date
  filter :application_end_date
  filter :application_expire_date
  filter :notifications_sent_at
  filter :data_synced_at
  filter :created_at

  scope :all, default: true
  scope :with_open_status

  show do
    attributes_table do
      row :unique_key
      row :application_number
      row :application_name
      row :application_type
      row :application_description
      row :work_type
      row :work_type_description
      row :application_status
      row :application_start_date
      row :application_end_date
      row :application_expire_date
      row :application_issued_date
      row :detail
      row :parking_meter_posting_or_bagging
      row :segment_label
      row :street_number_from
      row :street_number_to
      row :direction
      row :street_name
      row :suffix
      row :placement
      row :street_closure
      row :ward
      row :latitude
      row :longitude
      row :segment_from_lat
      row :segment_from_lng
      row :segment_to_lat
      row :segment_to_lng
      row :processed_alert_ids
      row :notifications_sent_at
      row :data_synced_at
      row :created_at
      row :updated_at
    end
  end

  form do |f|
    f.inputs "Permit Details" do
      f.input :application_status
      f.input :application_start_date, as: :datepicker
      f.input :application_end_date, as: :datepicker
      f.input :application_expire_date, as: :datepicker
      f.input :detail
      f.input :parking_meter_posting_or_bagging
      f.input :street_number_from
      f.input :street_number_to
      f.input :direction
      f.input :street_name
      f.input :suffix
      f.input :placement
      f.input :street_closure
      f.input :ward
    end
    f.actions
  end
end
