
program dmlparse, rclass

	syntax anything

	gettoken left 0: 0, parse("(") match(paren)
	local ycmd `left'
	gettoken left 0: 0, parse("(") match(paren)
	local dcmd `left'
	
	return local ycmd `ycmd'
	return local dcmd `dcmd'
		
end
