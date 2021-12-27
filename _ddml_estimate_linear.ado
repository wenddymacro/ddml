*** ddml estimation: linear models
program _ddml_estimate_linear, eclass sortpreserve

	syntax namelist(name=mname) [if] [in] ,		/// 
								[				///
								ROBust			///
								show(string)	///
								clear			/// deletes all tilde-variables (to be implemented)
								post(string)	/// specification to post/display
								REP(string)		/// resampling iteration to post/display or mean/median
								* ]
	// if post not specified, post optimal model
	if "`post'"=="" {
		local post "opt"
	}
	// if rep not specified, default is rep=1
	if "`rep'"=="" {
		local rep 1
	}
	// opt + mean/median not currently supported
	if "`post'"=="opt" & real("`rep'")==. {
		di as err "error - opt model not yet avaiable with mean/median"
		exit 198
	}
	
	
	// blank eqn - declare this way so that it's a struct and not transmorphic
	tempname eqn
	mata: `eqn' = init_eStruct()
	
	// base sample for estimation - determined by if/in
	marksample touse
	// also exclude obs already excluded by ddml sample
	qui replace `touse' = 0 if `mname'_sample==0

	// locals used below
	mata: st_local("model",`mname'.model)
	mata: st_local("nameY",`mname'.nameY)
	mata: st_local("nameD",invtokens(`mname'.nameD))
	mata: st_local("nameZ",invtokens((`mname'.nameZ)))
	mata: st_local("crossfitted",strofreal(`mname'.crossfitted))
	local numeqnD : word count `nameD'
	local numeqnZ : word count `nameZ'
	mata: st_local("nreps",strofreal(`mname'.nreps))

	if (`crossfitted'==0) {
		di as err "ddml model not cross-fitted; call `ddml crossfit` first"
		exit 198
	}
	
	// ssflag is a model characteristic but is well-defined only if every equation has multiple learners.
	// will need to check this...
	mata: st_local("ssflag",strofreal(`mname'.ssflag))
	
	// get varlists
	_ddml_make_varlists, mname(`mname')
	local yvars `r(yvars)'
	local dvars `r(dvars)'
	local zvars `r(zvars)'
	local zpos	`r(zpos_start)'

	// obtain all combinations
	_ddml_allcombos `yvars' - `dvars' - `zvars' ,	///
		`debug'										///
		zpos(`zpos')		 						///
		addprefix("")
	
	local ncombos = r(ncombos)
	local tokenlen = `ncombos'*2
	local ylist `r(ystr)'
	local Dlist `r(dstr)'
	local Zlist `r(zstr)' 
	
	tempname nmat bmat semat
	mata: `nmat' = J(`ncombos',3,"")
	mata: `bmat' = J(`ncombos'*`nreps',`numeqnD',.)
	mata: `semat' = J(`ncombos'*`nreps',`numeqnD',.)
	
	// simplest if put into a Mata string matrix
	tokenize `ylist' , parse("-")
	forvalues i=1/`ncombos' {
		local idx = 2*`i'-1
		mata: `nmat'[`i',1] = strtrim("``idx''")
	}
	tokenize `Dlist' , parse("-")
	forvalues i=1/`ncombos' {
		local idx = 2*`i'-1
		mata: `nmat'[`i',2] = strtrim("``idx''")
	}
	tokenize `Zlist' , parse("-")
	forvalues i=1/`ncombos' {
		local idx = 2*`i'-1
		mata: `nmat'[`i',3] = strtrim("``idx''")
	}
		
	*** shortstack names
	if `ssflag' {
		local Yss `nameY'_ss
		foreach var in `nameD' {
			local Dss `Dss' `var'_ss
			local DHss `DHss' `var'_ss_h
		}
		foreach var in `nameZ' {
			local Zss `Zss' `var'_ss
		}
	}
	
	forvalues m=1/`nreps' {
		
		// reset locals
		local Yopt
		local Dopt
		local Zopt
		
		*** retrieve best model
		mata: `eqn' = (`mname'.eqnAA).get("`nameY'")
		mata: st_local("Yopt",return_learner_item(`eqn',"opt","`m'"))
		foreach var in `nameD' {
			mata: `eqn' = (`mname'.eqnAA).get("`var'")
			mata: st_local("oneDopt",return_learner_item(`eqn',"opt","`m'"))
			local Dopt `Dopt' `oneDopt'
			// DHopt is stored in list Zopt
			if "`model'"=="ivhd" {
				mata: st_local("oneDHopt",return_learner_item(`eqn',"opt_h","`m'"))
				local Zopt `Zopt' `oneDHopt'
			}
		}
		// nameZ is empty for ivhd model
		foreach var in `nameZ' {
			mata: `eqn' = (`mname'.eqnAA).get("`var'")
			mata: st_local("oneZopt",return_learner_item(`eqn',"opt","`m'"))
			local Zopt `Zopt' `oneZopt'
		}
		
		// text used in output below
		if `nreps'>1 {
			local stext " (sample=`m')"
		}
		
		forvalues i = 1/`ncombos' {
			mata: st_local("y",`nmat'[`i',1])
			mata: st_local("d",`nmat'[`i',2])
			mata: st_local("z",`nmat'[`i',3])
			// check if opt for this resample; note === for D so order doesn't matter
			local isopt
			local isYopt : list Yopt == y
			local isDopt : list Dopt === d
			local isZopt : list Zopt === z
			if `isYopt' & `isDopt' & `isZopt' {
				local optspec`m' = `i'
				local isopt *
				local DMLtitle "Optimal DDML model"
			}
			else {
				local DMLtitle "DDML"
			}
			if "`model'"=="ivhd" {
				local dlist
				local zlist
				forvalues j = 1/`numeqnD' {
					tempvar zvar`j' 
					tempvar dx`j'
					local dh : word `j' of `z'
					local dt : word `j' of `d'
					local dd : word `j' of `nameD'
					qui gen double `zvar`j'' = `dh'_`m'-`dt'_`m' // E[D|ZX]-E[D|X] = instrument
					qui gen double `dx`j'' = `dd'-`dt'_`m' // D-E[D|X] = endogenous regressor
					local dlist `dlist' `dx`j''
					local zlist `zlist' `zvar`j''
				}
				local dvtnames `d'
				local zvtnames `z'
				local d `dlist'
				local z `zlist'
				local norep norep
			}
			qui _ddml_reg if `touse' ,								///
					nocons `robust'									///
					y(`y') yname(`nameY')							///
					d(`d') dnames(`nameD') dvtnames(`dvtnames') 	///
					z(`z') znames(`nameZ') zvtnames(`zvtnames')		///
					mname(`mname') rep(`m') `norep'
			estimates store `mname'_`i'_`m', title("Model `mname', specification `i' resample `m'`isopt'")
			mata: `bmat'[(`m'-1)*`ncombos'+`i',.] = st_matrix("e(b)")
			mata: `semat'[(`m'-1)*`ncombos'+`i',.] = sqrt(diagonal(st_matrix("e(V)"))')
		}
		
		if `ssflag' {
			if "`model'"=="ivhd" {
				local dlist
				local zlist
				forvalues j = 1/`numeqnD' {
					tempvar zvar`j' 
					tempvar dx`j'
					local dh : word `j' of `DHss'
					local dt : word `j' of `Dss'
					local dd : word `j' of `nameD'
					qui gen double `zvar`j'' = `dh'_`m'-`dt'_`m' // E[D|ZX]-E[D|X] = instrument
					qui gen double `dx`j'' = `dd'-`dt'_`m' // D-E[D|X] = endogenous regressor
					local dlist `dlist' `dx`j''
					local zlist `zlist' `zvar`j''
				}
				local dvtnames `Dss'
				local zvtnames `DHss'
				local d `dlist'
				local z `zlist'
				local norep norep
			}
			else {
				local d `Dss'
				local z `Zss'
			}
			qui _ddml_reg if `touse' ,								///
					nocons `robust'									///
					y(`Yss') yname(`nameY')							///
					d(`d') dnames(`nameD') dvtnames(`dvtnames') 	///
					z(`z') znames(`nameZ') zvtnames(`zvtnames')		///
					mname(`mname') rep(`m') `norep'
			estimates store `mname'_ss_`m', title("Model `mname', shorstack resample `m'")
		}

	}
	
	// aggregate across resamplings
	if `nreps' > 1 {
		// numbered specifications
		forvalues i = 1/`ncombos' {
			// default is mean
			qui _ddml_medmean, mname(`mname') nreps(`nreps') spec(`i') cmd(_ddml_reg)
			estimates store `mname'_`i'_mean, title("Model `mname', specification `i' resample mean")
			qui _ddml_medmean, mname(`mname') nreps(`nreps') spec(`i') cmd(_ddml_reg) median
			estimates store `mname'_`i'_median, title("Model `mname', specification `i' resample median")
		}
		// shortstack
		qui _ddml_medmean, mname(`mname') nreps(`nreps') spec(ss) cmd(_ddml_reg)
		estimates store `mname'_ss_mean, title("Model `mname', shortstack resample mean")
		qui _ddml_medmean, mname(`mname') nreps(`nreps') spec(ss) cmd(_ddml_reg) median
		estimates store `mname'_ss_median, title("Model `mname', shortstack resample median")
	}
	
	if "`show'"=="all" {
		forvalues m=1/`nreps' {
			// text used in output below
			if `nreps'>1 {
				local stext " (sample=`m')"
			}
			// all combos including optimal model
			forvalues i=1/`ncombos' {
				qui estimates restore `mname'_`i'_`m'
				if "`optspec`m''"=="`i'" {
					local DMLtitle "Optimal DDML model"
				}
				else {
					local DMLtitle "DDML"
				}
				di
				di as text "`DMLtitle'`stext':"
				_ddml_reg	// uses replay
				di
			}
			// shortstack
			qui estimates restore `mname'_ss_`m'
			di
			di as text "Shortstack DDML model`stext':"
			_ddml_reg	// uses replay
			di
		}
	}
		
	if "`show'"=="optimal" | "`show'"=="all" {
		forvalues m=1/`nreps' {
			qui estimates restore `mname'_`optspec`m''_`m'
			di
			di as text "Optimal DDML specification, resample `m': `optspec`m''"
			_ddml_reg
			di
		}
	}
		
	if "`show'"=="shortstack" | "`show'"=="all" {
		forvalues m=1/`nreps' {
			qui estimates restore `mname'_ss_`m'
			di
			di as text "Shortstack DDML model, resample `m':"
			_ddml_reg
			di
		}
	}
	
	di
	di as text "Summary DDML estimation results:"
	di as text "spec  r" %14s "Y learner" _c
	forvalues j=1/`numeqnD' {
		di as text %14s "D learner" %10s "b" %10s "SE" _c
	}
	if "`model'"=="ivhd" {
		forvalues j=1/`numeqnD' {
			di as text %14s "DH learner" _c
		}
	}
	forvalues j=1/`numeqnZ' {
		di as text %14s "Z learner" _c
	}
	di
	forvalues m=1/`nreps' {
		forvalues i=1/`ncombos' {
			mata: st_local("yt",`nmat'[`i',1])
			mata: st_local("dtlist",`nmat'[`i',2])
			mata: st_local("ztlist",`nmat'[`i',3])
			if "`optspec`m''"=="`i'" {
				di "*" _c
			}
			else {
				di " " _c
			}
			local specrep `: di %3.0f `i' %3.0f `m''
			// pad out to 6 spaces
			local specrep = (6-length("`specrep'"))*" " + "`specrep'"
			di %6s "{stata estimates replay `mname'_`i'_`m':`specrep'}" _c
			di %14s "`yt'" _c
			forvalues j=1/`numeqnD' {
				local vt : word `j' of `dtlist'
				mata: st_local("b",strofreal(`bmat'[(`m'-1)*`ncombos'+`i',`j']))
				mata: st_local("se",strofreal(`semat'[(`m'-1)*`ncombos'+`i',`j']))
				di %14s "`vt'" _c
				di %10.3f `b' _c
				local pse (`: di %6.3f `se'')
				di %10s "`pse'" _c
			}
			forvalues j=1/`numeqnZ' {
				local vt : word `j' of `ztlist'
				di %14s "`vt'" _c
			}
			if "`model'"=="ivhd" {
				forvalues j=1/`numeqnD' {
					local vt : word `j' of `ztlist'
					di %14s "`vt'" _c
				}
			}
			di
		}
		if `ssflag' {
			qui estimates restore `mname'_ss_`m'
			local specrep `: di "ss" %3.0f `m''
			// pad out to 6 spaces
			local specrep = "  " + "`specrep'"
			di %6s "{stata estimates replay `mname'_ss_`m':`specrep'}" _c			
			di %14s "[shortstack]" _c
			forvalues j=1/`numeqnD' {
				di %14s "[ss]" _c
				di %10.3f el(e(b),1,`j') _c
				local pse (`: di %6.3f sqrt(el(e(V),`j',`j'))')
				di %10s "`pse'" _c
			}
			if "`model'"=="ivhd" {
				forvalues j=1/`numeqnD' {
					di %14s "[ss]" _c
				}
			}
			forvalues j=1/`numeqnZ' {
				di %14s "[ss]" _c
			}
			di
		}
	}
	di as text "Mean/median:"
	foreach medmean in mean median {
		if "`medmean'"=="mean" {
			local mm mn
		}
		else {
			local mm md
		}
		forvalues i=1/`ncombos' {
			qui estimates restore `mname'_`i'_`medmean'
			mata: st_local("yt",`nmat'[`i',1])
			mata: st_local("dtlist",`nmat'[`i',2])
			mata: st_local("ztlist",`nmat'[`i',3])
			di " " _c
			local specrep `: di %3.0f `i' %3s "`mm'"'
			// pad out to 6 spaces
			local specrep = (6-length("`specrep'"))*" " + "`specrep'"
			di %6s "{stata estimates replay `mname'_`i'_`medmean':`specrep'}" _c
			di %14s "`yt'" _c
			forvalues j=1/`numeqnD' {
				local vt : word `j' of `dtlist'
				di %14s "`vt'" _c
				di %10.3f el(e(b),1,`j') _c
				local pse (`: di %6.3f sqrt(el(e(V),`j',`j'))')
				local pse (`: di %6.3f `se'')
				di %10s "`pse'" _c
			}
			forvalues j=1/`numeqnZ' {
				local vt : word `j' of `ztlist'
				di %14s "`vt'" _c
			}
			if "`model'"=="ivhd" {
				forvalues j=1/`numeqnD' {
					local vt : word `j' of `ztlist'
					di %14s "`vt'" _c
				}
			}
			di
		}
		if `ssflag' {
			qui estimates restore `mname'_ss_`medmean'
			local specrep `: di "ss" %3s "`mm'"'
			// pad out to 6 spaces
			local specrep = "  " + "`specrep'"
			di %6s "{stata estimates replay `mname'_ss_`medmean':`specrep'}" _c			
			di %14s "[shortstack]" _c
			forvalues j=1/`numeqnD' {
				di %14s "[ss]" _c
				di %10.3f el(e(b),1,`j') _c
				local pse (`: di %6.3f sqrt(el(e(V),`j',`j'))')
				di %10s "`pse'" _c
			}
			if "`model'"=="ivhd" {
				forvalues j=1/`numeqnD' {
					di %14s "[ss]" _c
				}
			}
			forvalues j=1/`numeqnZ' {
				di %14s "[ss]" _c
			}
			di
		}
	}
	
	// post selected estimates; rep is the resample number (default=1)
	if "`post'"=="opt" {
		qui estimates restore `mname'_`optspec`rep''_`rep'
		di
		di as text "Optimal DDML specification, resample `rep': `optspec`rep''"
		_ddml_reg
		di
	}
	else if "`post'"=="shortstack" {
		qui estimates restore `mname'_ss_`rep'
		di
		di as text "Shortstack DDML model, resample `rep':"
		_ddml_reg
		di	
	}
	else {
		// post macro should be an integer denoting the specification
		qui estimates restore `mname'_`post'_`rep'
		di
		di as text "DDML specification `post', resample `rep':"
		_ddml_reg
		di
	}
	
	// temp Mata object no longer needed
	cap mata: mata drop `eqn' `nmat' `bmat' `semat'



end

// adds model name prefixes to list of varnames
program define add_prefix, sclass
	syntax [anything] , prefix(name)

	// anything is a list of to-be-varnames that need prefix added to them
	foreach vn in `anything' {
		local vnames `vnames' `prefix'`vn' 
	}
	
	sreturn local vnames `vnames'
end

// adds rep number suffixes to list of varnames
program define add_suffix, sclass
	syntax [anything] , suffix(name)

	// anything is a list of to-be-varnames that need suffix added to them
	foreach vn in `anything' {
		local vnames `vnames' `vn'`suffix'
	}
	
	sreturn local vnames `vnames'
end


