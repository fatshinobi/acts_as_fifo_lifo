class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :name
      t.decimal :cost, precision: 8, scale: 2
      t.string :description

      t.timestamps
    end
  end
end
