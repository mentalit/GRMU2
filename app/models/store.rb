class Store < ApplicationRecord
	has_many :articles
	has_many :pairs
end
