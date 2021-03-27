class CreateAlerts < ActiveRecord::Migration[6.1]
  def change
    create_table :alerts, id: :uuid do |t|
      t.string :email
      t.string :phone
      t.boolean :confirmed
      t.references :area, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
