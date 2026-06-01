FactoryBot.define do
  factory :storage do
    name { "Storage #{SecureRandom.hex(4)}" }
    location { "Location #{SecureRandom.hex(2)}" }
  end

  factory :item do
    name { "Item #{SecureRandom.hex(4)}" }
    cost { 50.0 }
    description { "Test item description" }
  end

  factory :stock_transaction, class: "StockTransaction" do
    batch_number { "BATCH-#{SecureRandom.hex(4)}" }
    association :item
    association :storage
    operation_id { 1 }
    operation_type { "purchase" }
    quantity { 10 }
    unit_cost { 100.50 }
    time_at { Time.current }
  end
end
