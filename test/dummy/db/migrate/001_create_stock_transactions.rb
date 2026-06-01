class CreateStockTransactions < ActiveRecord::Migration[8.1]
  def change
    create_table :stock_transactions do |t|
      t.integer :storage_id, null: false
      t.integer :item_id, null: false
      t.string :batch_number
      t.integer :quantity, null: false
      t.decimal :unit_cost, precision: 10, scale: 2
      t.datetime :time_at
      t.integer :operation_id
      t.string :operation_type
    end
  end
end
