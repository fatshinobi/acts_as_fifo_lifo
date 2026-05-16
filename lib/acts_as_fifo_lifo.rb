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

    def acts_as_fifo(item_field:, qty_field:, cost_field:, time_field:, batch_field:, storage_field:, operation_field:, operation_type_field:)
      @fifo_item_field   = item_field
      @fifo_qty_field    = qty_field
      @fifo_cost_field   = cost_field
      @fifo_time_field   = time_field
      @fifo_batch_field  = batch_field
      @fifo_storage_field = storage_field
      @fifo_operation_field = operation_field
      @fifo_operation_type_field = operation_type_field
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
          # Round cost to two decimal places for consistency
          result << { batch_number: batch_number, qty: take, cost: batch_cost.round(2), batch_time: batch_time }
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
    def stock_balance_by_batches_calculation(storage_id: nil, item_id: nil, fields_info: {})
      storage_include = fields_info.dig(:storages, :include) || :storage
      item_include = fields_info.dig(:items, :include) || :item
      storage_field = fields_info.dig(:storages, :field) || :name
      item_field = fields_info.dig(:items, :field) || :name

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

      records = records.includes(storage_include, item_include)

      nested_records = records.group_by(&@fifo_storage_field.to_sym).transform_values do |storage_group|
        storage_group.group_by(&@fifo_item_field.to_sym)
      end

      results = []
      nested_records.each do |storage_id, items_hash|
        storage_name = items_hash.first.dig(1, 0)&.send(storage_include)&.send(storage_field) || "Storage #{storage_id}"
        # Level 1: Storage level
        puts "Storage ID: #{storage_id}"
        storage_hash = { details: { item: storage_name, qty: 0, batch_cost: "", cost: 0 }, children: [] }

        items_hash.each do |item_id, records|
          item_name = records.first&.send(item_include)&.send(item_field) || "Item #{item_id}"

          # Level 2: Item level
          puts "  Item ID: #{item_id}"
          item_hash = { details: { item: item_name, qty: 0, batch_cost: "", cost: 0 }, children: [] }
          # Round item level totals for display
          item_hash[:details][:cost] = item_hash[:details][:cost].round(2)
          item_hash[:details][:mean_cost] = item_hash[:details][:mean_cost].round(2) if item_hash[:details][:mean_cost].is_a?(Numeric)
          storage_hash[:children] << item_hash

          # Level 3: Batch records level (each record contains your select aliases)
          records.each do |record|
            puts "    Batch ID: #{record.batch_number} | Total Qty: #{record.total_qty} | Cost: #{record.batch_cost}"
              # Round batch_cost to two decimals for readability
              batch_cost = record.batch_cost.to_f.round(2)
              item_hash[:children] << { details: { item: record.batch_number, qty: record.total_qty.to_i, batch_cost: batch_cost, cost: (batch_cost * record.total_qty.to_i).round(2) }, children: [] }
              item_hash[:details][:qty] += record.total_qty.to_i
              # Use rounded batch_cost for accurate total cost aggregation
              batch_cost = record.batch_cost.to_f.round(2)
              total_batch_cost = (batch_cost * record.total_qty.to_i).round(2)
              item_hash[:details][:cost] = (item_hash[:details][:cost] + total_batch_cost).round(2)
              storage_hash[:details][:qty] += record.total_qty.to_i
              storage_hash[:details][:cost] = (storage_hash[:details][:cost] + total_batch_cost).round(2)
          end
        end
          # Round storage level totals for display
          storage_hash[:details][:cost] = storage_hash[:details][:cost].round(2)
          storage_hash[:details][:mean_cost] = storage_hash[:details][:mean_cost].round(2) if storage_hash[:details][:mean_cost].is_a?(Numeric)
          results << storage_hash
      end
      results
    end

    def stock_balance_by_items_calculation(storage_id: nil, item_id: nil, fields_info: {})
      storage_include = fields_info.dig(:storages, :include) || :storage
      item_include = fields_info.dig(:items, :include) || :item
      storage_field = fields_info.dig(:storages, :field) || :name
      item_field = fields_info.dig(:items, :field) || :name

      base_scope = all

      base_scope = base_scope.where(@fifo_storage_field => storage_id) if storage_id.present?
      base_scope = base_scope.where(@fifo_item_field => item_id) if item_id.present?

      records = base_scope.group(@fifo_storage_field, @fifo_item_field)
        .select(
          @fifo_storage_field,
          @fifo_item_field,
          "SUM(#{@fifo_qty_field}) AS total_qty",
          "SUM(#{@fifo_cost_field} * #{@fifo_qty_field}) / SUM(#{@fifo_qty_field}) AS item_cost"
        )

       records = records.includes(storage_include, item_include)
       results = []

       # Group records by storage then by item to build nested structure
       nested = records.group_by(&@fifo_storage_field.to_sym).transform_values do |storage_group|
         storage_group.group_by(&@fifo_item_field.to_sym)
       end

       nested.each do |storage_id, items_hash|
         # Resolve storage name via association
         first_record = items_hash.values.first.first
         storage_name = first_record&.send(storage_include)&.send(storage_field) || "Storage #{storage_id}"

         storage_hash = { details: { item: storage_name, qty: 0, mean_cost: "", cost: 0.0 }, children: [] }

         items_hash.each do |item_id, recs|
           first_item = recs.first
           item_name = first_item&.send(item_include)&.send(item_field) || "Item #{item_id}"
           item_hash = { details: { item: item_name, qty: 0, mean_cost: 0.0, cost: 0.0 }, children: [] }

           recs.each do |record|
             qty = record.total_qty.to_i
             cost_per = record.item_cost.to_f
              # Calculate total cost with two decimal precision
              total_cost = (qty * cost_per).round(2)
             item_hash[:details][:qty] += qty
             item_hash[:details][:cost] += total_cost
              # Calculate mean cost with two decimal precision to avoid floating point artifacts
              if item_hash[:details][:qty] > 0
                mean = item_hash[:details][:cost] / item_hash[:details][:qty]
                item_hash[:details][:mean_cost] = mean.round(2)
              end
             storage_hash[:details][:qty] += qty
              # Accumulate cost with high precision then round when presenting
              storage_hash[:details][:cost] += total_cost
           end

           storage_hash[:children] << item_hash
         end

         results << storage_hash
       end

       results
    end

    # Calculates stock movement for items, returning a two‑level nested structure.
    # The first level groups by item and shows the total balance (sum of qty) and
    # the average cost for that item. The second level lists each transaction
    # (grouped by batch) in chronological order, showing the running balance
    # after applying the transaction quantity.
    #
    # The implementation mirrors `stock_balance_by_items_calculation` but adds a
    # running balance column. It uses the same `fields_info` hash to resolve the
    # association names for storage and item includes.
    def stock_movement_calculation(storage_id: nil, item_id: nil, start_time: nil, end_time: nil, fields_info: {})
      storage_include = fields_info.dig(:storages, :include) || :storage
      item_include = fields_info.dig(:items, :include) || :item
      storage_field = fields_info.dig(:storages, :field) || :name
      item_field = fields_info.dig(:items, :field) || :name

      base_scope = all
      base_scope = base_scope.where(@fifo_storage_field => storage_id) if storage_id.present?
      base_scope = base_scope.where(@fifo_item_field => item_id) if item_id.present?
      base_scope = base_scope.where(@fifo_time_field => start_time..end_time) if start_time.present? && end_time.present?

      # Pull raw transaction rows ordered by time so we can compute a running balance.
      records = base_scope
        .select(
          @fifo_storage_field,
          @fifo_item_field,
          @fifo_batch_field,
          @fifo_time_field,
          @fifo_qty_field,
          @fifo_cost_field,
          @fifo_operation_field,
          @fifo_operation_type_field
        )
        .order(@fifo_time_field => :asc)

      records = records.includes(storage_include, item_include)

      # Group by storage then by item to build the required hierarchy.
      nested = records.group_by(&@fifo_storage_field.to_sym).transform_values do |storage_group|
        storage_group.group_by(&@fifo_item_field.to_sym)
      end

      results = []
      nested.each do |storage_id_key, items_hash|
        # Resolve storage name for display
        first_record = items_hash.values.first.first
        storage_name = first_record&.send(storage_include)&.send(storage_field) || "Storage #{storage_id_key}"
        storage_hash = { details: { item: storage_name, time: "", operation: "", qty: 0, cost: "", balance: 0 }, children: [] }

        items_hash.each do |item_id_key, recs|
          first_item = recs.first
          item_name = first_item&.send(item_include)&.send(item_field) || "Item #{item_id_key}"
          item_hash = { details: { item: item_name, time: "", operation: "", qty: 0, cost: "", balance: 0 }, children: [] }

          running_balance = 0
          recs.each do |record|
            qty = record.send(@fifo_qty_field).to_i
            cost = record.send(@fifo_cost_field).to_f
            running_balance += qty

              # Append child representing this transaction (batch)
              item_hash[:children] << {
                details: {
                  item: record.send(@fifo_batch_field),
                  time: record.send(@fifo_time_field).strftime("%F %T"),
                  operation: "#{record.send(@fifo_operation_type_field)} ##{record.send(@fifo_operation_field)}",
                  qty: qty,
                  cost: cost.round(2),
                  balance: running_balance
                },
                children: []
              }

            # Accumulate totals for the item level
            item_hash[:details][:qty] += qty
            item_hash[:details][:balance] = running_balance
          end

          storage_hash[:children] << item_hash
          # Update storage aggregates
          storage_hash[:details][:qty] += item_hash[:details][:qty]
          storage_hash[:details][:balance] += item_hash[:details][:balance]
        end

        results << storage_hash
      end
      results
    end
  end
end

ActiveRecord::Base.send :include, ActsAsFifoLifo
