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
           "MIN(#{@fifo_cost_field}) AS total_cost",
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

    # Calculates stock balance grouped by storage, item and batch.
    # Returns an array of hashes where each element represents a storage location
    # and contains two keys:
    #   * :groups  – summary per item (total qty and cost for the storage)
    #   * :details – list of batches for that storage with their qty and cost
    # The calculation uses the field names configured via `acts_as_fifo`.
    def stock_balance_by_batches_calculation(storage_id: nil, item_id: nil)
      base_scope = all

      base_scope = base_scope.where(@fifo_storage_field => storage_id) if storage_id.present?
      base_scope = base_scope.where(@fifo_item_field => item_id) if item_id.present?

      records = base_scope.group(@fifo_storage_field, @fifo_item_field, @fifo_batch_field)
        .select(
          @fifo_storage_field,
          @fifo_item_field,
          @fifo_batch_field,
          "SUM(#{@fifo_qty_field}) AS total_qty",
          "MIN(#{@fifo_cost_field}) AS batch_cost"
        )

      nested_records = records.group_by(&:storage_id).transform_values do |storage_group|
        storage_group.group_by(&:item_id)
      end

      results = []
      nested_records.each do |storage_id, items_hash|
        # Level 1: Storage level
        puts "Storage ID: #{storage_id}"
        storage_hash = { details: { item: "Storage #{storage_id}", qty: 0, batch_cost: "", cost: 0 }, children: [] }

        items_hash.each do |item_id, records|
          # Level 2: Item level
          puts "  Item ID: #{item_id}"
          item_hash = { details: { item: "Item #{item_id}", qty: 0, batch_cost: "", cost: 0 }, children: [] }
          storage_hash[:children] << item_hash

          # Level 3: Batch records level (each record contains your select aliases)
          records.each do |record|
            puts "    Batch ID: #{record.batch_number} | Total Qty: #{record.total_qty} | Cost: #{record.batch_cost}"
            item_hash[:children] << { details: { item: record.batch_number, qty: record.total_qty.to_i, batch_cost: record.batch_cost.to_f, cost: record.batch_cost.to_f * record.total_qty.to_i }, children: [] }
            item_hash[:details][:qty] += record.total_qty.to_i
            item_hash[:details][:cost] += record.batch_cost.to_f * record.total_qty.to_i
            storage_hash[:details][:qty] += record.total_qty.to_i
            storage_hash[:details][:cost] += record.batch_cost.to_f * record.total_qty.to_i
          end
        end
        results << storage_hash
      end
      results
    end
  end
end

ActiveRecord::Base.send :include, ActsAsFifoLifo
