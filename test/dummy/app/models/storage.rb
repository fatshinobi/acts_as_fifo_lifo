class Storage < ApplicationRecord
  has_many :stock_transactions, dependent: :destroy
end
