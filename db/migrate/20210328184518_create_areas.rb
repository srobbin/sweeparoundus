class CreateAreas < ActiveRecord::Migration[6.1]
  def change
    create_table :areas, id: :uuid do |t|
      t.integer :number
      t.integer :ward
      t.geometry :shape

      t.timestamps
    end
  end
end
