class Store < ApplicationRecord
	has_many :articles
	has_many :pairs
	has_many :aisles, through: :pairs


	def sales_methods
	    articles
	      .where.not(salesmethod: [nil, ""])
	      .distinct
	      .pluck(:salesmethod)
  	end

  	def hfbs
	    articles
	      .where.not(hfb: [nil, ""])
	      .distinct
	      .pluck(:hfb).sort
  	end

  	def pas
	    articles
	      .where.not(pa: [nil, ""])
	      .distinct
	      .pluck(:pa).sort
  	end
end
