class CreateSweeps < ActiveRecord::Migration[6.1]
  def change
    create_table :sweeps, id: :uuid do |t|
      t.date :date_1
      t.date :date_2
      t.date :date_3
      t.date :date_4
      t.references :area, null: false, foreign_key: true, type: :uuid

      t.timestamps
    end
  end
end
