if @rticle.dt = 0 and @article.mpq = 1 
	@article.new_assq = @article.rssq 
	@section.level_height = @article.rssq * @article.cp_height

if @rticle.dt = 0 and @article.mpq != 1 
	@section.level_height = (@article.rssq/@article.mpq) * @article.cp_height



if an article.DT = 1 OR (@article.dt = 0 AND @article.weight_g > 18143.7 OR ( @article.RSSQ > ( @article.palq / 2)) than it must be placed on level 00