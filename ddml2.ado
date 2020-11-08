*** 8 nov, 2020, 14:14 

program ddml2, eclass

	version 13
	
	local allargs `0'
	tokenize "`allargs'", parse(",")
	local mainargs `1'
	macro shift
	local restargs `*'

	local subcmd : word 1 of `mainargs'

	*** get latest version
	if "`subcmd'"=="update" {
		net install ddml, from(https://raw.githubusercontent.com/aahrens1/ddml/master/)
	} 
	
	*** describe model
	if "`subcmd'"=="desc" {
		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		// remaining args are temporary and for debugging only
		syntax , mname(name)

		mata: st_global("r(mstring)",`mname'.model)
		di "Model: `r(mstring)'"
		local model `r(mstring)'
		mata: st_global("r(mstring)",`mname'.nameY)
		di "Dependent variable (Y): `r(mstring)'"
		mata: st_global("r(mstring)",invtokens(`mname'.nameYtilde))
		di "Dependent variable (orthogonalized): `r(mstring)'"
		mata: st_global("r(mstring)",invtokens(`mname'.nameYopt))
		di "Minimum MSE orthogonalized dep var: `r(mstring)'"
		mata: st_global("r(mstring)",invtokens(`mname'.nameD))
		di "Causal variable(s) (D): `r(mstring)'"
		mata: st_global("r(mstring)",invtokens(`mname'.nameDtilde))
		di "Causal variable(s) (orthogonalized): `r(mstring)'"
		mata: st_global("r(mstring)",invtokens(`mname'.nameDopt))
		di "Minimum MSE orthogonalized causal var: `r(mstring)'"
		if ("`model'"=="iv") {
			mata: st_global("r(mstring)",invtokens(`mname'.nameZ))
			di "Excluded instrumental variable(s) (D): `r(mstring)'"
			mata: st_global("r(mstring)",invtokens(`mname'.nameZtilde))
			di "Excluded instrumental variable(s) (orthogonalized): `r(mstring)'"
			mata: st_global("r(mstring)",invtokens(`mname'.nameZopt))
			di "Minimum MSE orthogonalized IVs: `r(mstring)'"
		}
		
		// List equations
		// blank eqn - declare this way so that it's a struct and not transmorphic
		tempname eqn
		mata: `eqn' = init_eqnStruct()

		mata: st_numscalar("r(numeqns)",cols(`mname'.eqnlistY))
		local numeqnsY	= `r(numeqns)'
		di
		di "Number of Y estimating equations: `numeqnsY'"
		forvalues i=1/`numeqnsY' {
			mata: `eqn'=*(`mname'.eqnlistY[1,`i'])
			di "Estimating equation `i': " _c
			mata: st_numscalar("r(MSE)",`eqn'.MSE)
			di "MSE = " %10.6f `r(MSE)' _c
			mata: st_numscalar("r(crossfit)",`eqn'.crossfit)
			if `r(crossfit)'==0 {
				di " (no crossfit)"
			}
			else {
				di
			}
			mata: st_global("r(estring)",`eqn'.vname)
			di "  Variable: `r(estring)'" _c
			mata: st_global("r(estring)",`eqn'.vtilde)
			di _col(30) "Orthogonalized: `r(estring)'"
			mata: st_global("r(estring)",`eqn'.eststring)
			di "  Command: `r(estring)'"
		}
		mata: st_numscalar("r(numeqns)",cols(`mname'.eqnlistD))
		local numeqnsD	= `r(numeqns)'
		di
		di "Number of D estimating equations: `numeqnsD'"
		forvalues i=1/`numeqnsD' {
			mata: `eqn'=*(`mname'.eqnlistD[1,`i'])
			di "Estimating equation `i': " _c
			mata: st_numscalar("r(MSE)",`eqn'.MSE)
			di "MSE = " %10.6f `r(MSE)' _c
			mata: st_numscalar("r(crossfit)",`eqn'.crossfit)
			if `r(crossfit)'==0 {
				di " (no crossfit)"
			}
			else {
				di
			}
			mata: st_global("r(estring)",`eqn'.vname)
			di "  Variable: `r(estring)'" _c
			mata: st_global("r(estring)",`eqn'.vtilde)
			di _col(30) "Orthogonalized: `r(estring)'"
			mata: st_global("r(estring)",`eqn'.eststring)
			di "  Command: `r(estring)'"
		}
		if ("`model'"=="iv") {
			mata: st_numscalar("r(numeqns)",cols(`mname'.eqnlistZ))
			local numeqnsZ	= `r(numeqns)'
			di
			di "Number of Z estimating equations: `numeqnsZ'"
			forvalues i=1/`numeqnsZ' {
				mata: `eqn'=*(`mname'.eqnlistZ[1,`i'])
				di "Estimating equation `i': " _c
				mata: st_numscalar("r(MSE)",`eqn'.MSE)
				di "MSE = " %10.6f `r(MSE)' _c
				mata: st_numscalar("r(crossfit)",`eqn'.crossfit)
				if `r(crossfit)'==0 {
					di " (no crossfit)"
				}
				else {
					di
				}
				mata: st_global("r(estring)",`eqn'.vname)
				di "  Variable: `r(estring)'" _c
				mata: st_global("r(estring)",`eqn'.vtilde)
				di _col(30) "Orthogonalized: `r(estring)'"
				mata: st_global("r(estring)",`eqn'.eststring)
				di "  Command: `r(estring)'"
			}
		}

		// clear this global from Mata
		mata: mata drop `eqn'

	}
	
	*** initialize new estimation
	if "`subcmd'"=="init" {
		local model: word 2 of `mainargs'
		if ("`model'"!="partial"&"`model'"!="iv"&"`model'"!="interactive"&"`model'"!="late"&"`model'"!="optimaliv") {
			di as err "no or wrong model specified." 
			exit 1
		}
		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		syntax , mname(name)
		mata: `mname'=init_ddmlStruct()
		// fill by hand
		mata: `mname'.model		= "`model'"

	} 

	*** add equation  
	if "`subcmd'"=="yeq"|"`subcmd'"=="deq"|"`subcmd'"=="zeq" {

		** check that equation is consistent with model
		if ("`subcmd'"=="yeq"&"`model'"=="optimaliv") {
			di as err "not allowed; yeq not allowed with `model'"
		}
		if ("`subcmd'"=="zeq"&("`model'"=="optimaliv"|"`model'"=="partial"|"`model'"=="interactive")) {
			di as err "not allowed; deq not allowed with `model'"
		}

		** check that ddml has been initialized
		// to add

		** parsing
		// macro options has eqn to be estimated set off from the reset by a :
		tokenize `" `restargs' "', parse(":")
		// parse character is in macro `2'
		local eqn `3'
		local 0 "`1'"
		syntax ,	mname(name)		///
					vname(name)		///
					gen(name)		///
					[ NOCROSSfit ]

		// subcmd macro tells add_eqn(.) which list to add it to
		mata: add_eqn(`mname', "`subcmd'", "`vname'", "`gen'", "`eqn'", "`nocrossfit'")
		if "`subcmd'"=="yeq" {
			// check if nameY is already there; if it is, must be identical to vname here
			mata: st_global("r(vname)",`mname'.nameY)
			if "`r(vname)'"=="" {
				mata: `mname'.nameY		= "`vname'"
			}
			else if "`r(vname)'"~="`vname'" {
				di as err "error - incompatible y variables"
				exit 198
			}
		}
		if "`subcmd'"=="deq" {
			// check if nameD already has vname; if not, add it to the list
			mata: st_global("r(vname)",invtokens(`mname'.nameD))
			if "`r(vname)'"=="" {
				mata: `mname'.nameD		= "`vname'"
			}
			else {
				local dlist `r(vname)' `vname'
				local dlist : list uniq dlist
				mata: `mname'.nameD		= tokens("`dlist'")
			}
		}
		if "`subcmd'"=="zeq" {
			// check if nameZ already has vname; if not, add it to the list
			mata: st_global("r(vname)",invtokens(`mname'.nameZ))
			if "`r(vname)'"=="" {
				mata: `mname'.nameZ		= "`vname'"
			}
			else {
				local zlist `r(vname)' `vname'
				local zlist : list uniq zlist
				mata: `mname'.nameZ		= tokens("`zlist'")
			}
		}
		di as text "Equation successfully added."
	}

	*** cross-fitting
	if "`subcmd'" =="crossfit" {

		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		syntax , mname(name)

		mata: st_global("r(model)",`mname'.model)

		if ("`r(model)'"=="partial") {
		_ddml_crossfit_partial `restargs'
		}
		if ("`r(model)'"=="iv") {
		_ddml_crossfit_partial `restargs'
		}
		if ("`r(model)'"=="interactive") {
		_ddml_crossfit_interactive `restargs'
		}
		if ("`r(model)'"=="late") {
		_ddml_crossfit_late `restargs'
		}
		if ("`r(model)'"=="optimaliv") {
		_ddml_crossfit_optimaliv `restargs'
		}
	}

	*** estimate
	if "`subcmd'" =="estimate" {
		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		syntax , mname(name)
		
		// check that mname is the name of a Mata ddmlStruct
		mata: st_global("r(structname)",structname(`mname'))
		if ("`r(structname)'" ~= "ddmlStruct") {
			di as err "you need to provide the name of the ddmlStruct with the crossfit results"
			exit 198
		}

		mata: st_global("r(model)",`mname'.model)

		if ("`r(model)'"=="partial") {
			_ddml_estimate_partial `mname', `options'
		}
		if ("`r(model)'"=="iv") {
			_ddml_estimate_iv `mname', `options'
		}
		if ("`r(model)'"=="interactive") {
			_ddml_estimate_interactive, `options'
		}
		if ("`r(model)'"=="late") {
			_ddml_estimate_late, `options'
		}
		if ("`r(model)'"=="optimaliv") {
			_ddml_estimate_optimaliv, `options'
		}
	}
end


********************************************************************************
*** Mata section															 ***
********************************************************************************

mata:

struct ddmlStruct init_ddmlStruct()
{
	struct ddmlStruct scalar	d

	d.eqnlistY		= J(0,0,NULL)
	d.eqnlistD		= J(0,0,NULL)
	d.eqnlistZ		= J(0,0,NULL)
	d.nameY			= ""
	d.nameYtilde	= ""
	d.nameYopt		= ""
	d.nameD			= ""
	d.nameDtilde	= ""
	d.nameDopt		= ""
	d.nameZ			= ""
	d.nameZtilde	= ""
	d.nameZopt		= ""
	return(d)
}

struct eqnStruct init_eqnStruct()
{
	struct eqnStruct scalar		e
	return(e)
}

void add_eqn(						struct ddmlStruct m,
									string scalar eqtype,
									string scalar vname,
									string scalar vtilde,
									string scalar estcmd,
									string scalar nocrossfit)
{
	struct eqnStruct scalar		e
	e.vname			= vname
	e.vtilde		= vtilde
	e.eststring		= estcmd
	e.command		= tokens(estcmd)[1,1]
	e.crossfit		= (nocrossfit=="")

	if (eqtype=="yeq") {
		if (cols(m.eqnlistY)==0) {
			m.eqnlistY	= &e
		}
		else {
			m.eqnlistY	= (m.eqnlistY, &e)
		}
	}
	else if (eqtype=="deq") {
		if (cols(m.eqnlistD)==0) {
			m.eqnlistD	= &e
		}
		else {
			m.eqnlistD	= (m.eqnlistD, &e)
		}
	}
	else if (eqtype=="zeq") {
		if (cols(m.eqnlistZ)==0) {
			m.eqnlistZ	= &e
		}
		else {
			m.eqnlistZ	= (m.eqnlistZ, &e)
		}
	}

	if (eqtype=="yeq") {
		if (m.nameYtilde=="") {
			m.nameYtilde	= vtilde
		}
		else {
			m.nameYtilde	= (m.nameYtilde, vtilde)
		}
	}
	else if (eqtype=="deq") {
		if (m.nameDtilde=="") {
			m.nameDtilde	= vtilde
		}
		else {
			m.nameDtilde	= (m.nameDtilde, vtilde)
		}
	}
	else if (eqtype=="zeq") {
		if (m.nameZtilde=="") {
			m.nameZtilde	= vtilde
		}
		else {
			m.nameZtilde	= (m.nameZtilde, vtilde)
		}
	}
}

end 

/*

ATE <- function(y, d, my_d1x, my_d0x, md_x)
{
  return( mean( (d * (y - my_d1x) / md_x) -  ((1 - d) * (y - my_d0x) / (1 - md_x)) + my_d1x - my_d0x ) );
}

SE.ATE <- function(y, d, my_d1x, my_d0x, md_x)
{
  return( sd( (d * (y - my_d1x) / md_x) -  ((1 - d) * (y - my_d0x) / (1 - md_x)) + my_d1x - my_d0x )/sqrt(length(y)) );
}

LATE <- function(y, d, z, my_z1x, my_z0x, mz_x, md_z1x, md_z0x)
{
  return( mean( z * (y - my_z1x) / mz_x -  ((1 - z) * (y - my_z0x) / (1 - mz_x)) + my_z1x - my_z0x ) / 
			mean( z * (d - md_z1x) / mz_x -  ((1 - z) * (d - md_z0x) / (1 - mz_x)) + md_z1x - md_z0x ) );
}

SE.LATE <- function(y, d, z, my_z1x, my_z0x, mz_x, md_z1x, md_z0x)
{
  return( sd(( z * (y - my_z1x) / mz_x -  ((1 - z) * (y - my_z0x) / (1 - mz_x)) + my_z1x - my_z0x ) / 
			   mean( z * (d - md_z1x) / mz_x -  ((1 - z) * (d - md_z0x) / (1 - mz_x)) + md_z1x - md_z0x )) / sqrt(length(y)) );
}
