






def length_classifier
	tall_art = []
	short_art =[]

	if @article.dt = 1 || (@article.dt = 0 && (@article.RSSQ > @article.PALQ))
		article_width = @article.ul_width_gross
		article_length = @article.ul_length_gross
		article_height = @article.ul_height_gross
	else
		article_width = @article.cp_width
		article_length = @article.cp_length
		article_height = @article.cp_height
	end

	@articles.each do |art|
		if art.article_length > 1524
			tall_art << art
		else
			short_art << art 
		end
	end
end


