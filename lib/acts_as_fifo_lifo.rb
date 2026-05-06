require "acts_as_fifo_lifo/version"
require "acts_as_fifo_lifo/railtie"

module ActsAsFifoLifo
  # Implements FIFO/LIFO behavior configuration.
  #
  # @param options [Hash] configuration options
  # @option options [Symbol,String] :item_field   Field name for the item identifier
  # @option options [Symbol,String] :qty_field    Field name for the quantity
  # @option options [Symbol,String] :cost_field   Field name for the cost
  # @option options [Symbol,String] :time_field   Field name for the timestamp
  # @option options [Symbol,String] :batch_field  Field name for the batch identifier
  # @option options [Symbol,String] :storage_field Field name for the storage identifier
  #
  # The method simply stores the provided field names in instance variables so they can be
  # used later in the FIFO/LIFO logic.
  def act_as_fifo(item_field:, qty_field:, cost_field:, time_field:, batch_field:, storage_field:)
    @fifo_item_field   = item_field
    @fifo_qty_field    = qty_field
    @fifo_cost_field   = cost_field
    @fifo_time_field   = time_field
    @fifo_batch_field  = batch_field
    @fifo_storage_field = storage_field
  end
end
