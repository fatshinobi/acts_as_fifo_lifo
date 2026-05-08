require "acts_as_fifo_lifo/version"
require "acts_as_fifo_lifo/railtie"

module ActsAsFifoLifo
  extend ActiveSupport::Concern

  class_methods do
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

    def acts_as_fifo(item_field:, qty_field:, cost_field:, time_field:, batch_field:, storage_field:)
      @fifo_item_field   = item_field
      @fifo_qty_field    = qty_field
      @fifo_cost_field   = cost_field
      @fifo_time_field   = time_field
      @fifo_batch_field  = batch_field
      @fifo_storage_field = storage_field
    end

    # Returns an ordered list of batches needed to satisfy a quantity request.
    # Each element is a hash with :batch_number and :qty keys.
    #
    # @param item_id [Integer] the identifier of the item
    # @param store_id [Integer] the identifier of the storage location
    # @param qty [Integer] the required quantity
    # @return [Array<Hash{batch_number: String, qty: Integer}>]
    def get_batches_for(item_id, store_id, qty)
      # Build a base scope using the configured field names.
      base_scope = where(
        @fifo_item_field => item_id,
        @fifo_storage_field => store_id
      )

       # Build a query that groups by batch, sums the quantity, and orders
       # batches by the earliest transaction time using MIN to satisfy
       # ONLY_FULL_GROUP_BY.
       batch_records = base_scope
         .group(@fifo_batch_field)
         .select(
           @fifo_batch_field,
           "SUM(#{@fifo_qty_field}) AS total_qty",
           "SUM(#{@fifo_cost_field}) AS total_cost",
           "MIN(#{@fifo_time_field}) AS first_time"
         )
         .having("SUM(#{@fifo_qty_field}) > 0")
         .order("first_time ASC")

       result = []
       remaining = qty

       batch_records.each do |rec|
         batch_number = rec.send(@fifo_batch_field)
         batch_qty = rec.total_qty.to_i
         batch_cost = rec.total_cost.to_f
         batch_time = rec.first_time

         take = [ batch_qty, remaining ].min
         result << { batch_number: batch_number, qty: take, cost: batch_cost, batch_time: batch_time }
         remaining -= take
         break if remaining <= 0
       end

       result
    end
  end
end

ActiveRecord::Base.send :include, ActsAsFifoLifo
