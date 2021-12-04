* notes
* vtype was used for predicting values by fold, now applies to vtilde as well
* eqntype replaced by resid option (default=fitted)
* default is additive-type crossfitting; treatvar option triggers interactive-type crossfitting

* single equation version returns scalars:
*   r(mse)
*   r(N)
* and matrices:
*   r(N_folds)
*   r(mse_folds)

* multiple equation version returns matrices:
*   r(N_folds_list)
*   r(mse_folds_list)
*   r(N_list)
*   r(mse_list)
*   r(N_folds)
*   r(mse_folds)


mata:

struct eStruct {
	real matrix vlist
	real matrix vtlist
	real matrix elist
	real matrix emlist
	real matrix eolist
	real matrix vtlisth
	real matrix elisth
	real matrix emlisth
	real matrix eolisth
}

struct eStruct init_eStruct()
{
	struct eStruct scalar	d

	d.vlist		= J(1,0,"")
	d.vtlist	= J(1,0,"")
	d.elist		= J(1,0,"")
	d.emlist	= J(1,0,"")
	d.eolist	= J(1,0,"")
	d.vtlisth	= J(1,0,"")
	d.elisth	= J(1,0,"")
	d.emlisth	= J(1,0,"")
	d.eolisth	= J(1,0,"")
	return(d)
}

end

program define initialize_eqn_info, rclass

	syntax [anything] [if] [in] ,					/// 
							[						///
							sname(name)				/// name of mata struct
							vlist(string)			/// names of original variables
							vtlist(string)			/// names of corresponding tilde variables
							estring(string asis)	/// names of estimation strings
													/// need asis option in case it includes strings
							vtlisth(string)			/// intended for lists of E[D^|X] where D^=E[D|XZ]=vtilde()
							estringh(string asis)	/// names of LIE estimation strings
													/// need asis option in case it includes strings
							NOIsily					///
							]
	
	if "`noisily'"=="" {
		local qui quietly
	}

	tempname t
	
	mata: `sname'			= init_eStruct()
	// in two steps, to accommodate singleton lists (which are otherwise string scalars and not matrices
	mata: `t' = tokens("`vlist'")
	mata: `sname'.vlist		= `t'
	mata: `t' = tokens("`vtlist'")
	mata: `sname'.vtlist	= `t'
	parse_estring, sname(`sname') estring(`estring') `noisily'

	if "`vtlisth'"~="" {
		mata: `t' = tokens("`vtlisth'")
		mata: `sname'.vtlisth	= `t'
		parse_estring, sname(`sname') estring(`estringh') h `noisily'
	}
	
	mata: st_local("numeqns",strofreal(cols(`sname'.elist)))
	return scalar numeqns = `numeqns'

end

program define parse_estring, rclass

	syntax [anything] [if] [in] ,					/// 
							[						///
							sname(name)				/// name of mata struct
							estring(string asis)	/// names of estimation strings
													/// need asis option in case it includes strings
							h						/// indicates LIE eqn
							NOIsily					///
							]
	
	if "`noisily'"=="" {
		local qui quietly
	}

	// set struct fields
	if "`h'"=="" {
		local elist		elist
		local emlist	emlist
		local eolist	eolist
	}
	else {
		local elist		elisth
		local emlist	emlisth
		local eolist	eolisth
	}
	
	tempname t
	
	local doparse = 1
	while `doparse' {
		
		tokenize `"`estring'"', parse("||")
		mata: `t' = "`1'"
		// used below with syntax command
		local 0 `"`1'"'
		
		// catch special case - a single | appears inside the estimation string
		if "`2'"=="|" & "`3'"~="|" {
			mata: `t' = "`1' `2' `3'"
			// used below with syntax command
			local 0 `"`1' `2' `3'"'
			mac shift 2
			local estring `*'
			tokenize `"`estring'"', parse("||")
		}		
		
		mata: `sname'.`elist'	= (`sname'.`elist', `t')
		`qui' di "est: `0'"
		syntax [anything] , [*]
		local est_main `anything'
		local est_options `options'
		`qui' di "est_main: `est_main'"
		`qui' di "est_options: `est_options'"
		mata: `t' = "`est_main'"
		mata: `sname'.`emlist'	= (`sname'.`emlist', `t')
		mata: `t' = "`est_options'"
		mata: `sname'.`eolist'	= (`sname'.`eolist', `t')
		

		if "`2'"~="|" & "`3'"~="|" {
			// done parsing
			local doparse = 0
		}

		mac shift 3
		
		local estring `*'
	}

end

program define crossfit, rclass sortpreserve

	syntax [anything] [if] [in] ,					/// 
							[						///
							kfolds(integer 0)		/// if not supplied, calculate
							NOIsily					///
							foldvar(name)			/// must be numbered 1...K where K=#folds
							resid					///
							vtilde(namelist)		/// name(s) of fitted variable
							vtilde0(name)			/// name of fitted variable
							vtilde1(name)			/// name of fitted variable
							vname(varlist)			/// name of original variable
							eststring(string asis)	/// estimation string
													/// need asis option in case it includes strings
							vtype(string)			/// datatype of fitted variable; default=double
							treatvar(varname)		/// 1 or 0 RHS variable; relevant for interactive model only
													/// if omitted then default is additive model
							shortstack(name)		///
													/// 
													/// options specific to LIE/DDML-IV
							vtildeh(namelist)		/// intended for E[D^|X] where D^=E[D|XZ]=vtilde()	
							eststringh(string asis)	/// est string for E[D^|XZ]		
							]

	// temporary renaming until options above renamed
	local vlist `vname'
	local vtlist `vtilde'
	local vtlisth `vtildeh'

	// LIE => we want predicted values not resids
	if "`vtlisth'"~="" {
		local resid
	}

	marksample touse
	
	if "`noisily'"=="" {
		local qui quietly
	}

	*** setup
	
	tempname eqn_info
	initialize_eqn_info, sname(`eqn_info') vlist(`vlist') vtlist(`vtlist') estring(`eststring')	///
						vtlisth(`vtlisth') estringh(`eststringh')								///
						`noisily'
	local numeqns = r(numeqns)
	
	*** syntax
	if "`shortstack'"~="" & `numeqns'==1 {
		di as err "error - shortstack option available only for multiple learners"
		exit 198
	}

	** indicator for LIE/optimal-IV model
	if "`eststringh'"!="" local lie lie
	
	// datatype for fitted values/residuals
	if "`vtype'"=="" {
		local vtype double
	}
	
	// create blank fitted variable(s)
	forvalues i=1/`numeqns' {
		if "`treatvar'"=="" {
			tempvar vhat`i' vres`i'
			qui gen `vtype' `vhat`i''=.
			qui gen `vtype' `vres`i''=.
		} 
		else {
			qui cap gen `vtype' `vtilde0'=.
			qui cap gen `vtype' `vtilde1'=.		
		}
		if "`lie'"!="" {
			// in-sample predicted values for E[D|ZX]; resids not needed
			tempvar vhath_is`i' vhath`i'
			qui gen `vtype' `vhath_is`i''=.
			qui gen `vtype' `vhath`i''=.
		}
	}

	// if kfolds=0 then find number of folds
	// note this requires that foldvar takes values 1..K
	if `kfolds'==0 {
		qui sum `foldvar', meanonly
		local kfolds = r(max)
	}

	// save pystacked weights
	tempname pysw pysw0 pysw1 pysw_t pysw_h

	// crossfit
	di
	di as text "Cross-fitting fold " _c
	forvalues k = 1(1)`kfolds' {

		di as text "`k' " _c

		forvalues i=1/`numeqns' {
			mata: st_local("est_main",`eqn_info'.emlist[`i'])
			mata: st_local("est_options",`eqn_info'.eolist[`i'])
			mata: st_local("vname",`eqn_info'.vlist[`i'])
			mata: st_local("vtilde",`eqn_info'.vtlist[`i'])
			if "`lie'"!="" {
				// LIE locals
				mata: st_local("est_main_h",`eqn_info'.emlisth[`i'])
				mata: st_local("est_options_h",`eqn_info'.eolisth[`i'])
				mata: st_local("vhath",`eqn_info'.vtlisth[`i'])
			}
			
			if "`treatvar'"=="" & "`lie'"=="" {
			
				tempvar vhat_k
				
				// estimate excluding kth fold
				`qui' `est_main' if `foldvar'!=`k' & `touse', `est_options'
				local cmd `e(cmd)'
	
				// save pystacked weights
				if ("`cmd'"=="pystacked") {
					if (`k'==1) {
						mat `pysw' = e(weights)
					}
					else {
						mat `pysw_t' = e(weights)
						mat `pysw' = (`pysw',`pysw_t')
					}
				}
	
				// get fitted values and residuals for kth fold	
				qui predict `vtype' `vhat_k' if `foldvar'==`k' & `touse'
	
				// get predicted values
				qui replace `vhat`i'' = `vhat_k' if `foldvar'==`k' & `touse'
				qui replace `vres`i'' = `vname' - `vhat_k' if `foldvar'==`k' & `touse'
	
			}
	
			else if "`treatvar'"!="" & "`lie'"=="" {		// interactive models
	
				// outcome equation so estimate separately
	
				// for treatvar = 1
				// estimate excluding kth fold
				`qui' `est_main' if `foldvar'!=`k' & `treatvar' == 1 & `touse', `est_options'
				local cmd `e(cmd)'
	
				// save pystacked weights
				if ("`cmd'"=="pystacked") {
					if (`k'==1) {
						mat `pysw0' = e(weights)
					}
					else {
						mat `pysw_t' = e(weights)
						mat `pysw0' = (`pysw0',`pysw_t')
					}
				}
	
	
				// get fitted values for kth fold	
				tempvar vhat_k
				qui predict `vtype' `vhat_k' if `foldvar'==`k' & `touse'
				qui replace `vtilde1' = `vhat_k' if `foldvar'==`k' & `touse'
	
				// for treatvar = 0
				// estimate excluding kth fold
				`qui' `est_main' if `foldvar'!=`k' & `treatvar' == 0 & `touse', `est_options'
	
				// save pystacked weights
				if ("`cmd'"=="pystacked") {
					if (`k'==1) {
						mat `pysw1' = e(weights)
					}
					else {
						mat `pysw_t' = e(weights)
						mat `pysw1' = (`pysw1',`pysw_t')
					}
				}
	
				// get fitted values for kth fold	
				tempvar vhat_k
				qui predict `vtype' `vhat_k' if `foldvar'==`k' & `touse'
				qui replace `vtilde0' = `vhat_k' if `foldvar'==`k' & `touse'

			}
	
			else if "`lie'"!="" {
	
				tempvar vhat_k // stores predicted values for E[D|ZX] temporarily
				tempvar vhath_k // stores predicted values for E[D^|X] temporarily
	
				// line may be unnecessary
				qui replace `vhath_is`i''=.
	
				// Step I: estimation of E[D|XZ]=D^
				// estimate excluding kth fold
				`qui' `est_main' if `foldvar'!=`k' & `touse', `est_options'
				local cmd `e(cmd)'
	
				// save pystacked weights
				if ("`cmd'"=="pystacked") {
					if (`k'==1) {
						mat `pysw' = e(weights)
					}
					else {
						mat `pysw_t' = e(weights)
						mat `pysw' = (`pysw',`pysw_t')
					}
				}
				
				// get fitted values (in and out of sample)
				qui predict `vtype' `vhat_k' if `touse'
	
				// get out-of-sample predicted values
				qui replace `vhat`i'' = `vhat_k' if `foldvar'==`k' & `touse'
	
				// get in-sample predicted values
				qui replace `vhath_is`i'' = `vhat_k' if `foldvar'!=`k' & `touse'
	
				// Step II: estimation of E[D^|X]
	
				// replace {D}-placeholder in estimation string with variable name
				local est_main_h_k = subinstr("`est_main_h'","{D}","`vhath_is`i''",1)
	
				// estimation	
				`qui' `est_main_h_k' if `foldvar'!=`k' & `touse', `est_options_h'
				local cmd_h `e(cmd)'
	
				// save pystacked weights
				if ("`cmd_h'"=="pystacked") {
					if (`k'==1) {
						mat `pysw_h' = e(weights)
					}
					else {
						mat `pysw_t' = e(weights)
						mat `pysw_h' = (`pysw_h',`pysw_t')
					}
				}
	
				// get fitted values  
				qui predict `vtype' `vhath_k' if `touse'
	
				// get out-of-sample predicted values
				qui replace `vhath`i'' = `vhath_k' if `foldvar'==`k' & `touse'
	
			}
			
			// should perhaps do this elsewhere
			if `k'==1 {
				local cmd_list `cmd_list' `cmd'
			}
			
		}
	}
	
	// last fold, insert new line
	di "...complete"

	tempname mse_list N_list mse_folds_list N_folds_list
	tempname mse_h_list N_h_list mse_h_folds_list N_h_folds_list
	
	forvalues i=1/`numeqns' {

		// maybe move below into LIE block ... unless this is supposed to be used in the first block below?
		if "`lie'"!="" {
			// vtilde has fitted values
			tempvar vresh_sq
			qui gen double `vresh_sq' = (`vhat`i'' - `vhath`i'')^2 if `touse'		
		}
	
		// vtilde, mspe, etc.
		if "`treatvar'"=="" {
	
			mata: st_local("vname",`eqn_info'.vlist[`i'])
			mata: st_local("vtilde",`eqn_info'.vtlist[`i'])
			if "`resid'"=="" {
				// vtilde is predicted values
				qui gen `vtilde' = `vhat`i''
			}
			else {
				// vtilde is residuals
				qui gen `vtilde' = `vres`i''
			}
	
			// calculate and return mspe and sample size
			tempvar vres_sq
			qui gen double `vres_sq' = `vres`i''^2 if `touse'
		
			// additive-type model
			qui sum `vres_sq' if `touse', meanonly
			local mse			= r(mean)
			local N				= r(N)
			tempname mse_folds N_folds
			forvalues k = 1(1)`kfolds' {
				qui sum `vres_sq' if `touse' & `foldvar'==`k', meanonly
				mat `mse_folds' = (nullmat(`mse_folds'), r(mean))
				qui count if `touse' & `foldvar'==`k' & `vres_sq'<.
				mat `N_folds' = (nullmat(`N_folds'), r(N))
			}
		
			mat `mse_list'			= (nullmat(`mse_list') \ `mse')
			mat `N_list'			= (nullmat(`N_list') \ `N')
			mat `mse_folds_list'	= (nullmat(`mse_folds_list') \ `mse_folds')
			mat `N_folds_list'		= (nullmat(`N_folds_list')\ `N_folds')
		}
		else {
	
			// calculate and return mspe and sample size
			tempvar vtilde0_sq vtilde1_sq
			// vtilde has fitted values
			qui gen double `vtilde0_sq' = (`vlist' - `vtilde0')^2 if `treatvar' == 0 & `touse'
			qui gen double `vtilde1_sq' = (`vlist' - `vtilde1')^2 if `treatvar' == 1 & `touse'
	
			// interactive-type model, return mse separately for treatvar =0 and =1
			qui sum `vtilde0_sq' if `treatvar' == 0 & `touse', meanonly
			return scalar mse0	= r(mean)
			local N				= r(N)
			return scalar N0	= r(N)
			qui sum `vtilde1_sq' if `treatvar' == 1 & `touse', meanonly
			return scalar mse1	= r(mean)
			local N				= `N' + r(N)
			return scalar N1	= r(N)
			tempname mse0_folds N0_folds mse1_folds N1_folds
			forvalues k = 1(1)`kfolds' {
				qui sum `vtilde0_sq' if `treatvar' == 0 & `touse' & `foldvar'==`k', meanonly
				mat `mse0_folds' = (nullmat(`mse0_folds'), r(mean))
				qui sum `vtilde1_sq' if `treatvar' == 1 & `touse' & `foldvar'==`k', meanonly
				mat `mse1_folds' = (nullmat(`mse1_folds'), r(mean))
				qui count if `treatvar' == 0 & `touse' & `foldvar'==`k' & `vtilde1_sq'<.
				mat `N0_folds' = (nullmat(`N0_folds'), r(N))
				qui count if `treatvar' == 1 & `touse' & `foldvar'==`k' & `vtilde0_sq'<.
				mat `N1_folds' = (nullmat(`N1_folds'), r(N))
			}
			return mat mse0_folds	= `mse0_folds'
			return mat mse1_folds	= `mse1_folds'
			return mat N0_folds		= `N0_folds'
			return mat N1_folds		= `N1_folds'
	
		}
		
		if "`lie'"!="" {
			qui sum `vresh_sq' if `touse', meanonly
			local mse_h			= r(mean)
			local N_h			= r(N)	
			tempname mse_h_folds N_h_folds
			forvalues k = 1(1)`kfolds' {
				qui sum `vresh_sq' if `touse' & `foldvar'==`k', meanonly
				mat `mse_h_folds' = (nullmat(`mse_h_folds'), r(mean))
				qui count if `touse' & `foldvar'==`k' & `vresh_sq'<.
				mat `N_h_folds' = (nullmat(`N_h_folds'), r(N))
			}
			mat `mse_h_list'		= (nullmat(`mse_h_list') \ `mse_h')
			mat `N_h_list'			= (nullmat(`N_h_list') \ `N_h')
			mat `mse_h_folds_list'	= (nullmat(`mse_h_folds_list') \ `mse_h_folds')
			mat `N_h_folds_list'	= (nullmat(`N_h_folds_list')\ `N_h_folds')
		}
	}
	
	// shortstack
	if "`shortstack'"~="" & `numeqns'>1 {
		if "`treatvar'"=="" {
		 	forvalues i=1/`numeqns' {
		 		local vhats `vhats' `vhat`i''
		 	}
		 	tempvar vss
		 	`qui' di as text "Stacking NNLS:"
			`qui' _ddml_nnls `vname' `vhats', gen(`shortstack') double
			
			if "`resid'"~="" {
				// vtilde is the residual
				qui replace `shortstack' = `vname' - `shortstack'
			}
		}
	}

	if "`treatvar'"=="" {
		return mat mse_folds		= `mse_folds'
		return mat N_folds			= `N_folds'
		return scalar mse			= `mse'

		return mat mse_list			= `mse_list'
		return mat N_list			= `N_list'
		return mat mse_folds_list	= `mse_folds_list'
		return mat N_folds_list		= `N_folds_list'
	}
	if "`lie'"~="" {
		return scalar N_h			= `N_h'
	
		return mat mse_h_folds		= `mse_h_folds'
		return mat N_h_folds		= `N_h_folds'
		return scalar mse_h			= `mse_h'
		
		return mat mse_h_list		= `mse_h_list'
		return mat N_h_list			= `N_h_list'
		return mat mse_h_folds_list	= `mse_h_folds_list'
		return mat N_h_folds_list	= `N_h_folds_list'
	}

	return scalar N			= `N'
	return local cmd		`cmd'
	return local cmd_h		`cmd_h'
	if ("`cmd'"=="pystacked" & "`lie'"=="" & "`treatvar'"=="") return mat pysw = `pysw' // pystacked weights
	if ("`cmd'"=="pystacked" & "`lie'"=="" & "`treatvar'"!="") return mat pysw0 = `pysw0'
	if ("`cmd'"=="pystacked" & "`lie'"=="" & "`treatvar'"!="") return mat pysw1 = `pysw1'
	if ("`cmd'"=="pystacked" & "`lie'"!="") return mat pysw_h 		= `pysw_h'
 
	return local cmd_list	`cmd_list'
	
 end
 