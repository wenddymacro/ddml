*** 20 nov, 2020
* ddml v0.2

program ddml, eclass

	version 13
	
	local allargs `0'
	tokenize "`allargs'", parse(",")
	local mainargs `1'
	macro shift
	local restargs `*'

	local subcmd : word 1 of `mainargs'
	
	local allsubcmds	update describe save export use drop copy init yeq deq zeq crossfit estimate
	if strpos("`allsubcmds'","`subcmd'")==0 {
		di as err "error - unknown subcommand `subcmd'"
		exit 198
	}

	*** get latest version
	if "`subcmd'"=="update" {
		net install ddml, from(https://raw.githubusercontent.com/aahrens1/ddml/master/)
	} 
	
	*** describe model
	if abbrev("`subcmd'",4)=="desc" {
		local 0 "`restargs'"
		syntax , mname(name) [ * ]
		check_mname "`mname'"
		_ddml_describe `mname', `options'
	}

	*** save model
	if "`subcmd'"=="save" {
		local fname: word 2 of `mainargs'
		local 0 "`restargs'"
		syntax , mname(name) [ * ]
		check_mname "`mname'"
		_ddml_save, mname(`mname') fname(`fname') `options'

	}
	
	*** export model
	if "`subcmd'"=="export" {
		local fname: word 2 of `mainargs'
		local 0 "`restargs'"
		syntax , mname(name) [ * ]
		check_mname "`mname'"
		_ddml_export, mname(`mname') fname(`fname') `options'

	}
	
	*** use model
	if "`subcmd'"=="use" {
		local fname: word 2 of `mainargs'
		local 0 "`restargs'"
		syntax , mname(name) [ * ]
		// no need to check name
		_ddml_use, mname(`mname') fname(`fname') `options'
	}

	*** drop model
	if "`subcmd'"=="drop" {
		local 0 "`restargs'"
		syntax , mname(name)
		check_mname "`mname'"
		_ddml_drop, mname(`mname')
	}

	*** copy model
	if "`subcmd'"=="copy" {
		local 0 "`restargs'"
		syntax , mname(name) newmname(name)
		check_mname "`mname'"
		_ddml_copy, mname(`mname') newmname(`newmname')
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
		// fold variable is option; default is ddmlfold
		syntax , mname(name)
		mata: `mname'=init_ddmlStruct()
		// create and store id variable
		cap drop `mname'_id
		qui gen double `mname'_id	= _n
		mata: `mname'.id			= st_data(., "`mname'_id")
		// fill by hand
		mata: `mname'.model			= "`model'"
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

		** check that ddml has been initialized
		// to add
		check_mname "`mname'"

		// subcmd macro tells add_eqn(.) which list to add it to
		mata: add_eqn(`mname', "`subcmd'", "`vname'", "`gen'", "`eqn'", "`nocrossfit'")
		local newentry `r(newentry)'
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
		if `newentry' {
			di as text "Equation successfully added."
		}
		else {
			di as text "Equation successfully replaced."
		}
	}

	*** cross-fitting
	if "`subcmd'" =="crossfit" {

		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		syntax , mname(name) [*]
		check_mname "`mname'"

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
		_ddml_crossfit_interactive `restargs'
		}
		if ("`r(model)'"=="optimaliv") {
		_ddml_crossfit_optimaliv `restargs'
		}
	}

	*** estimate
	if "`subcmd'" =="estimate" {
		local 0 "`restargs'"
		// mname is required; could make optional with a default name
		syntax , mname(name) [*]
		check_mname "`mname'"

		mata: st_global("r(model)",`mname'.model)

		if ("`r(model)'"=="partial") {
			_ddml_estimate_partial `mname', `options'
		}
		if ("`r(model)'"=="iv") {
			_ddml_estimate_iv `mname', `options'
		}
		if ("`r(model)'"=="interactive") {
			_ddml_estimate_interactive `mname', `options'
		}
		if ("`r(model)'"=="late") {
			_ddml_estimate_late `mname', `options'
		}
		if ("`r(model)'"=="optimaliv") {
			_ddml_estimate_optimaliv `mname', `options'
		}
	}
end

prog define check_mname

	args mname

	mata: st_local("isnull",strofreal(findexternal("`mname'")==NULL))
	if `isnull' {
		di as err "model `mname' not found"
		exit 3259
	}
	
	mata: st_local("eltype",eltype(`mname'))
	if "`eltype'"~="struct" {
		di as err "model `mname' is not a struct"
		exit 3259
	}

	mata: st_local("structname",structname(`mname'))
	if "`structname'"~="ddmlStruct" {
		di as err "model `mname' is not a ddmlStruct"
		exit 3000
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

struct ddmlStruct use_model(		string scalar fname)
{
	struct ddmlStruct scalar	m
	fh = fopen(fname,"r")
	m = fgetmatrix(fh,1)	// nonzero second argument required for "strict"
	fclose(fh)
	return(m)
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
	struct eqnStruct scalar		e, e0
	e.vname			= vname
	e.vtilde		= vtilde
	e.eststring		= estcmd
	e.command		= tokens(estcmd)[1,1]
	e.crossfit		= (nocrossfit=="")

	newentry		= 1
	
	if (eqtype=="yeq") {
		if (cols(m.eqnlistY)==0) {
			m.eqnlistY	= &e
		}
		else {
			// look for existing entry
			for (i=1;i<=cols(m.eqnlistY);i++) {
				e0 = *(m.eqnlistY[i])
				if (e0.vtilde==vtilde) {
					// replace
					m.eqnlistY[i] = &e
					newentry = 0
				}
			}
			if (newentry==1) {
				// new entry
				m.eqnlistY	= (m.eqnlistY, &e)
			}
		}
	}
	else if (eqtype=="deq") {
		if (cols(m.eqnlistD)==0) {
			m.eqnlistD	= &e
		}
		else {
			// look for existing entry
			for (i=1;i<=cols(m.eqnlistD);i++) {
				e0 = *(m.eqnlistD[i])
				if (e0.vtilde==vtilde) {
					// replace
					m.eqnlistD[i] = &e
					newentry = 0
				}
			}
			if (newentry==1) {
				// new entry
				m.eqnlistD	= (m.eqnlistD, &e)
			}
		}
	}
	else if (eqtype=="zeq") {
		if (cols(m.eqnlistZ)==0) {
			m.eqnlistZ	= &e
		}
		else {
			// look for existing entry
			for (i=1;i<=cols(m.eqnlistZ);i++) {
				e0 = *(m.eqnlistZ[i])
				if (e0.vtilde==vtilde) {
					// replace
					m.eqnlistZ[i] = &e
					newentry = 0
				}
			}
			if (newentry==1) {
				// new entry
				m.eqnlistZ	= (m.eqnlistZ, &e)
			}
		}
	}

	// add to list of tilde variables if a new entry
	if (newentry) {
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
	
	st_global("r(newentry)",strofreal(newentry))
}

end 
