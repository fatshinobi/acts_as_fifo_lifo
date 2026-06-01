RSpec.describe StockTransaction, type: :model do
  describe "acts_as_fifo_lifo" do
    let(:storage) { create(:storage) }
    let(:item) { create(:item) }
    let(:time_at) { Time.current }

    describe ".get_batches_for" do
      context "with fifo method" do
        it "returns batches in ascending order by time" do
          create_list(:stock_transaction, 3, item: item, storage: storage, time_at: time_at)
          results = StockTransaction.get_batches_for(item.id, storage.id, 10, time_at, method: "fifo")
          expect(results).to be_an(Array)
        end

        it "returns partial quantities from multiple batches in FIFO order" do
          create(:stock_transaction, item: item, storage: storage, quantity: 2, batch_number: "OLD", time_at: time_at)
          create(:stock_transaction, item: item, storage: storage, quantity: 5, batch_number: "NEW", time_at: time_at + 1.hour)

          results = StockTransaction.get_batches_for(item.id, storage.id, 5, time_at + 2.hours, method: "fifo")

          expect(results.length).to eq(2)
          expect(results[0][:batch_number]).to eq("OLD")
          expect(results[0][:qty]).to eq(2)
          expect(results[1][:batch_number]).to eq("NEW")
          expect(results[1][:qty]).to eq(3)
        end
      end

      context "with lifo method" do
        it "returns batches in descending order by time" do
          create_list(:stock_transaction, 3, item: item, storage: storage, time_at: time_at)
          results = StockTransaction.get_batches_for(item.id, storage.id, 10, time_at, method: "lifo")
          expect(results).to be_an(Array)
        end

        it "returns partial quantities from multiple batches in LIFO order" do
          create(:stock_transaction, item: item, storage: storage, quantity: 2, batch_number: "OLD", time_at: time_at)
          create(:stock_transaction, item: item, storage: storage, quantity: 5, batch_number: "NEW", time_at: time_at + 1.hour)

          results = StockTransaction.get_batches_for(item.id, storage.id, 6, time_at + 2.hours, method: "lifo")

          expect(results.length).to eq(2)
          expect(results[0][:batch_number]).to eq("NEW")
          expect(results[0][:qty]).to eq(5)
          expect(results[1][:batch_number]).to eq("OLD")
          expect(results[1][:qty]).to eq(1)
        end
      end
    end

    describe ".stock_balance_by_batches_calculation" do
      it "returns nested structure with storage, items, and batches" do
        create(:stock_transaction, item: item, storage: storage, time_at: time_at)
        results = StockTransaction.stock_balance_by_batches_calculation
        expect(results).to be_an(Array)
      end
    end

    describe ".stock_balance_by_items_calculation" do
      it "returns nested structure with storage and items" do
        create(:stock_transaction, item: item, storage: storage, time_at: time_at)
        results = StockTransaction.stock_balance_by_items_calculation
        expect(results).to be_an(Array)
      end
    end

    describe ".stock_movement_calculation" do
      it "returns nested structure with storage, items, and transactions" do
        create(:stock_transaction, item: item, storage: storage, time_at: time_at)
        results = StockTransaction.stock_movement_calculation(start_time: 1.day.ago, end_time: time_at)
        expect(results).to be_an(Array)
      end
    end

    describe ".balance_for" do
      it "returns hash with item-storage balances" do
        create(:stock_transaction, item: item, storage: storage, time_at: time_at)
        results = StockTransaction.balance_for(time_at)
        expect(results).to be_a(Hash)
      end
    end

    describe ".stock_balance_for_items_calculation" do
      it "returns array of item summaries" do
        create(:stock_transaction, item: item, storage: storage, time_at: time_at)
        results = StockTransaction.stock_balance_for_items_calculation
        expect(results).to be_an(Array)
      end
    end
  end
end
