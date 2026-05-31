# ActsAsFifoLifo

A Rails gem providing FIFO (First In, First Out) and LIFO (Last In, First Out) inventory calculation methods for ActiveRecord models.

## Installation

Add this line to your application's Gemfile:

```ruby
gem "acts_as_fifo_lifo"
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install acts_as_fifo_lifo
```

## Usage

Include the module in your ActiveRecord model and configure the field mappings:

```ruby
class StockTransaction < ApplicationRecord
  acts_as_fifo_lifo item_field: :item_id,
    qty_field: :quantity,
    cost_field: :unit_cost,
    time_field: :created_at,
    batch_field: :batch_number,
    storage_field: :storage_id,
    operation_field: :operation_id,
    operation_type_field: :operation_type

end
```

## Demo application:

[FIFO LIFO Warehouse Application](https://github.com/fatshinobi/fifo_lifo_warehouse)

### Available Methods

#### `get_batches_for(item_id, store_id, qty, time_at, method: "fifo")`

Returns an ordered list of batches needed to satisfy a quantity request.

```ruby
StockTransaction.get_batches_for(1, 1, 100, Time.current, method: "fifo")
# => [{ batch_number: "B001", qty: 50, cost: 10.5, batch_time: 2024-01-01 10:00:00 }, ...]
```

#### `stock_balance_by_batches_calculation(storage_id: nil, item_id: nil, to_time: nil, fields_info: {})`

Returns stock balance grouped by storage, item, and batch in a nested structure.

#### `stock_balance_by_items_calculation(storage_id: nil, item_id: nil, to_time: nil, fields_info: {})`

Returns stock balance grouped by storage and item with mean cost calculation.

#### `stock_movement_calculation(storage_id: nil, item_id: nil, start_time: nil, end_time: nil, fields_info: {})`

Returns stock movement with running balance, grouped by storage, item, and transaction.

#### `stock_balance_for_items(item_id: nil, to_time: nil, limit: nil, fields_info: {})`

Returns an ActiveRecord::Relation with aggregate stock data per item (total_qty and mean_cost).

#### `stock_balance_for_items_calculation(item_id: nil, to_time: nil, fields_info: {})`

Transforms item stock balance records into a structured array format.

## Contributing

Contribution directions go here.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).