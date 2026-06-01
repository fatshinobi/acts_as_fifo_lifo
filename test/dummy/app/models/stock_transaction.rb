class StockTransaction < ApplicationRecord
  belongs_to :item
  belongs_to :storage

  acts_as_fifo_lifo(
    item_field: :item_id,
    qty_field: :quantity,
    cost_field: :unit_cost,
    time_field: :time_at,
    batch_field: :batch_number,
    storage_field: :storage_id,
    operation_field: :operation_id,
    operation_type_field: :operation_type
  )
end
