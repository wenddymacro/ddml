program define _ddml_make_varlists, rclass

	syntax [anything], mname(name)
	
	// blank eqn - declare this way so that it's a struct and not transmorphic
	tempname eqn
	mata: `eqn' = init_eStruct()

	// locals used below
	mata: st_local("model",`mname'.model)
	
	mata: st_local("nameY",`mname'.nameY)
	mata: st_local("nameD",invtokens(`mname'.nameD))
	mata: st_local("nameZ",invtokens(`mname'.nameZ))
	// as used in other code - below these macros are numbers of learners
	local numeqnD	: word count `nameD'
	local numeqnZ	: word count `nameZ'
	
	mata: `eqn' = (*(`mname'.peqnAA)).get("`nameY'")
	mata: st_local("vtlistY",invtokens(`eqn'.vtlist))
	local numlnrY : word count `vtlistY'
	
	if `numeqnD' {
		foreach var of varlist `nameD' {
			mata: `eqn' = (*(`mname'.peqnAA)).get("`var'")
			mata: st_local("vtlistD",invtokens(`eqn'.vtlist))
			tempname Dt_list
			local `Dt_list' `vtlistD'
			local Dorthog_lists `Dorthog_lists' `Dt_list'
		}
	}

	if `numeqnZ' {
		foreach var of varlist `nameZ' {
			mata: `eqn' = (*(`mname'.peqnAA)).get("`var'")
			mata: st_local("vtlistZ",invtokens(`eqn'.vtlist))
			tempname Zt_list
			local `Zt_list' `vtlistZ'
			local Zorthog_lists `Zorthog_lists' `Zt_list'
		}
	}

	local dash
	foreach vl in `Dorthog_lists' {
		local Dtilde `Dtilde' `dash' ``vl''
		local dash -
	}
	local dash
	foreach vl in `Zorthog_lists' {
		local Ztilde `Ztilde' `dash' ``vl''
		local dash -
	}

	// clear from Mata
	mata: mata drop `eqn'
	
	return scalar dpos_end = `numeqnD' + 1
	return scalar dpos_start = 2
	if (`numeqnZ'>0) {
		return scalar zpos_start = `numeqnD' +2
		return scalar zpos_end = `numeqnD' + `numeqnZ' + 1
	}
	if ("`model'"=="optimaliv"|"`model'"=="optimaliv_nolie") {		
		return scalar zpos_start = `numeqnD' +2
		// return scalar zpos_end = `numeqnD' + `numeqnDH' + 1
		// not sure this will work
		return scalar zpos_end = 2*`numeqnD' + 1
	}
	return scalar numD = `numeqnD'
	return scalar numZ = `numeqnZ'
	return local yvars `vtlistY'
	return local dvars `Dtilde'
	return local zvars `Ztilde' `DHtilde'

end



mata: 
struct eqnStruct init_eqnStruct()
{
	struct eqnStruct scalar		e
	return(e)
}
end
