** last edited: 14 nov 2020

program define allcombos2, rclass
	version 13
	
	tokenize `0' , parse("|")
	
	tempname out
	mata: `out' = get_combos("`0'")
	mata: st_rclear()
	mata: mat_to_string(`out')
	mata: mat_to_colstring(`out')

	di "`r(str)'"
	di "`r(colstr1)'"
end

mata: 

string matrix get_combos(string scalar input)
{

	input = tokens(input,"|")

	for (i=1; i<=cols(input); i=i+2) {

		vars = input[1,i]
		vars = ustrtrim(vars)

		if (i==1) {

			out = tokens(vars)'

		}
		else {

			// put next set of variables into mata vector
			x = tokens(vars)'
				
			// save dimensions
			orows = rows(out)
			xrows = rows(x)
				
			// duplicate rows			
			out = Jsort(out,xrows)
			x = J(orows,1,x)
				
			// column bind
			out = (out,x)
			
		}

	}
	
	return(out)

}

void mat_to_string(string matrix inmat)
{
	inmat
	r = rows(inmat)
	for (i=1;i<=r;i++) {

		if (i==1) {
			str = invtokens(inmat[i,]) 
		}
		else {
			str = str + " | " + invtokens(inmat[i,]) 
		}
	} 

	st_global("r(str)",str)

}

void mat_to_colstring(string matrix inmat)
{
	inmat
	k = cols(inmat)
	st_numscalar("r(k)",k)
	for (j=1;j<=k;j++) {

		str = invtokens(inmat[,j]') 
		st_global("r(colstr"+strofreal(j)+")",str)

	} 

}

string matrix Jsort(string matrix mat,
				real scalar rep
)
{
	r = rows(mat)
	for (i=1;i<=r;i++) {
		if (i==1) {
			out = J(rep,1,mat[i,])
		} 
		else {
			out = (out\J(rep,1,mat[i,]))
		}
	}
	return(out)
}

end
		