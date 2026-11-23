class CreateOneOffNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :one_off_notifications, id: :uuid do |t|
      t.references :alert, type: :uuid, null: false, foreign_key: { on_delete: :cascade }
      t.string :campaign, null: false
      t.datetime :queued_at, null: false

      t.index [ :campaign, :alert_id ], unique: true
    end
  end
end
