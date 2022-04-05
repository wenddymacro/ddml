program define _ddml_extract, rclass

	syntax [name] , [				///
				mname(name)			///
				ename(name)			///
				vname(name)			///
				show(name)			///
				keys				///
				key1(string)		///
				key2(string)		///
				key3(string)		///
				subkey1(string)		///
				subkey2(string)		///
				stata				///
				]
	
	*** syntax checks
	if "`mname'`ename'"=="" {
		di as err "error - must provide either mname(.) or ename(.)"
		exit 198
	}
	if "`mname'"~="" & "`ename'"~="" {
		di as err "error - incompatible options mname(.) and ename(.)"
		exit 198
	}
	// show macro can be lower or upper case; upper required below
	local show = upper("`show'")
	
	local keysflag = ("`keys'"~="")
	
	tempname obj mtemp etemp

	if "`mname'"=="" {
		mata: `mtemp' = init_mStruct()
		mata: `obj' = m_ddml_extract("",`mtemp',"`ename'",`ename',`keysflag',"`show'","`vname'","`key1'","`key2'","`key3'","`subkey1'","`subkey2'")
	}
	else if "`ename'"=="" {
		mata: `etemp' = init_eStruct()
		mata: `obj' = m_ddml_extract("`mname'",`mname',"",`etemp',`keysflag',"`show'","`vname'","`key1'","`key2'","`key3'","`subkey1'","`subkey2'")
	}
	
	// return matrix values; transfer from Mata to Stata so that any preexisting r(.) values are cleared
	local matlist `r(matlist)'
	foreach mname in `matlist' {
		tempname `mname'
		mat `mname' = r(`mname')
	}
	foreach mname in `matlist' {
		return matrix `mname' = `mname'
	}
	
	if "`namelist'"=="" {
		mata: `obj'
		mata: mata drop `obj'
	}
	else if "`stata'"=="" {
		cap mata: mata drop `namelist'
		mata: mata rename `obj' `namelist'
	}
	else {
		mata: st_local("eltype",eltype(`obj'))
		mata: st_local("orgtype",orgtype(`obj'))
		if "`eltype'"=="string" {
			mata: st_global("`namelist'",`obj')
		}
		else if "`orgtype'"=="scalar" {
			mata: st_numscalar("`namelist'",`obj')
		}
		else if ("`orgtype'"=="matrix") | ("`orgtype'"=="rowvector") | ("`orgtype'"=="colvector") {
			mata: st_matrix("`namelist'",`obj')
		}
		else {
			di as err "unsupported eltype `eltype' / orgtype `orgtype'"
			exit 198
		}
	}
	cap mata: mata drop `mtemp'
	cap mata: mata drop `etemp'
	
end

********************************************************************************
*** Mata section															 ***
********************************************************************************

mata:

transmorphic m_ddml_extract(		string scalar mname,		///
									struct mStruct d,			///
									string scalar ename,		///
									struct eStruct e,			///
									real scalar keysflag,		///
									string scalar show,			///
									string scalar vname,		///
									string scalar key1,			///
									string scalar key2,			///
									string scalar key3,			///
									string scalar subkey1,		///
									string scalar subkey2		///
									)
{
	struct eStruct scalar eqn
	class AssociativeArray scalar AA

	if (show=="PYSTACKED") {
		rmatlist = J(1,0,"")
		vnames =(d.eqnAA).keys()
		vnames = sort(vnames,(1::cols(vnames))')
		for (i=1;i<=rows(vnames);i++) {
			eqn = (d.eqnAA).get(vnames[i])
			vkeys = (eqn.resAA).keys()
			vkeys = sort(vkeys,(1::cols(vkeys))')
			for (j=1;j<=rows(vkeys);j++) {
				if (strpos(vkeys[j,2],"stack_weights")) {
					rname=vkeys[j,1]
					if (vkeys[j,2]=="stack_weights") {
						rname=rname+"_"+vkeys[j,3]
						rmatlist = (rmatlist, rname)
						DZeq01 = ""
					}
					else if (vkeys[j,2]=="stack_weights0") {
						if (d.model=="interactive") {
							rname = rname + "_Deq0"
						}
						else {	// LATE
							rname = rname + "_Zeq0"
						}
						rname=rname+"_"+vkeys[j,3]
						rmatlist = (rmatlist, rname)
						DZeq01 = "0"
					}
					else if (vkeys[j,2]=="stack_weights1") {
						if (d.model=="interactive") {
							rname = rname + "_Deq1"
						}
						else {	// LATE
							rname = rname + "_Zeq1"
						}
						rname=rname+"_"+vkeys[j,3]
						rmatlist = (rmatlist, rname)
						DZeq01 = "1"
					}
					rmat = (eqn.resAA).get(vkeys[j,.])
					st_matrix("r("+rname+")",rmat)
					base_est = tokens((eqn.lrnAA).get((vkeys[j,1],"stack_base_est")))'
					rstripe = (J(rows(base_est),1,""), base_est)
					st_matrixrowstripe("r("+rname+")",rstripe)
					// display
					display_pystacked_weights(d,vnames[i],rname,rmat,base_est,DZeq01)
				}
			}
		}
		st_global("r(matlist)",invtokens(sort(rmatlist,1)))
	}
	else if ((show=="MSE") | (show=="N")) {
		rmatlist = J(1,0,"")
		vnames =(d.eqnAA).keys()
		vnames = sort(vnames,(1::cols(vnames))')
		for (i=1;i<=rows(vnames);i++) {
			eqn = (d.eqnAA).get(vnames[i])
			rmatmse = J(0,1,.)
			rmatmse_folds = J(0,d.kfolds,.)
			reqn = J(0,1,"")
			rvtilde = J(0,1,"")
			rsmp = J(0,1,.)
			DZeq01 = J(0,1,.)
			vkeys = (eqn.resAA).keys()
			// sort keys by vtilde, rep, and lastly "MSE" or "MSE_folds"
			// means that when looping through, when j=MSE then j+1=MSE_folds for same vtilde and rep
			vkeys = sort(vkeys,(1,3,2))
			for (j=1;j<=rows(vkeys);j++) {
				if ((strpos(vkeys[j,2],show)==1) & (strpos(vkeys[j,2],"folds")==0)) {
					rmatmse = (rmatmse \ (eqn.resAA).get(vkeys[j,.]))
					reqn = (reqn \ vnames[i])
					if (strpos(vkeys[j,2],"0")) {
						DZeq01 = (DZeq01 \ 0)
					}
					else if (strpos(vkeys[j,2],"1")) {
						DZeq01 = (DZeq01 \ 1)
					}
					rvtilde = (rvtilde \ (vkeys[j,1]))
					rsmp = (rsmp \ strtoreal(vkeys[j,3]))
				}
				if ((strpos(vkeys[j,2],show)==1) & (strpos(vkeys[j,2],"folds")>0)) {
					rmatmse_folds =(rmatmse_folds \ (eqn.resAA).get(vkeys[j,.]))
				}
			}
			// store as r(.) macro
			// if interactive or LATE, include column for D/Z=0 or D/Z=1
			if (rows(DZeq01)>0) {
				rmat = (DZeq01, rsmp, rmatmse, rmatmse_folds)
				if (d.model=="interactive") {
					cstripe = ("D=0/1" \ "rep" \ "full_sample")
				}
				else {	// LATE
					cstripe = ("Z=0/1" \ "rep" \ "full_sample")
				}
			}
			else {
				rmat = (rsmp, rmatmse, rmatmse_folds)
				cstripe = ("rep" \ "full_sample")
			}
			rname = vnames[i]+"_mse"
			st_matrix("r("+rname+")",rmat)
			rstripe = (J(rows(rmat),1,""), rvtilde)
			st_matrixrowstripe("r("+rname+")",rstripe)
			// add fold numbers to column stripe
			for (k=1;k<=d.kfolds;k++) {
				cstripe = (cstripe \ "fold"+strofreal(k))
			}
			cstripe = (J(rows(cstripe),1,""), cstripe)
			st_matrixcolstripe("r("+rname+")",cstripe)
			rmatlist = (rmatlist, rname)
			st_global("r(matlist)",invtokens(sort(rmatlist,1)))
			display_mse(d, show, reqn, rvtilde, DZeq01, rsmp, rmatmse, rmatmse_folds)
		}
	}
	else if (ename~="") {
		// eStruct provided
		if (keysflag) {
			printf("{txt}AA keys for eqn %s.lrnAA:\n",ename)
			keymat = (e.lrnAA).keys()
			sort(keymat,(1::cols(keymat))')
			printf("{txt}AA keys for eqn %s.resAA:\n",ename)
			keymat = (e.resAA).keys()
			sort(keymat,(1::cols(keymat))')
		}
		else if (key3=="") {
			// only 2 keys, it's lrnAA
			return((e.lrnAA).get((key1,key2)))
		}
		else {
			// 3 keys, it's resAA		
			return((e.resAA).get((key1,key2,key3)))
		}
	}
	else if (mname~="") {
		// mStruct provided
		
		if ((keysflag) & (vname=="")) {
			if (vname=="") {
				// no vname means show the keys for the model struct AAs
				printf("{txt}AA keys for %s.eqnAA:\n",mname)
				keymat =(d.eqnAA).keys()
				keymat = sort(keymat,(1::cols(keymat))')
				keymat
				printf("{txt}AA keys for %s.estAA:\n",mname)
				keymat = (d.estAA).keys()
				keymat = sort(keymat,(1::cols(keymat))')
				keymat
				for (i=1;i<=rows(keymat);i++) {
					if (classname((d.estAA).get((keymat[i,.])))=="AssociativeArray") {
						k1 = keymat[i,1]
						k2 = keymat[i,2]
						printf("{txt}AA keys for %s.estAA, key 1=%s and key 2=%s:\n",mname,k1,k2)
						AA = (d.estAA).get((keymat[i,.]))
						keymat2 = AA.keys()
						sort(keymat2,(1::cols(keymat2))')
					}
				}
			}
		}
		
		if (keysflag) {
			if (vname~="") {
				vlist = J(1,1,vname)
			}
			else {
				vlist = (d.nameY, d.nameD, d.nameZ)
			}
			for (v=1;v<=cols(vlist);v++) {
				eqn = (d.eqnAA).get(vlist[v])
				printf("{txt}AA keys for eqn %s.lrnAA:\n",vlist[v])
				keymat = (eqn.lrnAA).keys()
				sort(keymat,(1::cols(keymat))')
				printf("{txt}AA keys for eqn %s.resAA:\n",vlist[v])
				keymat = (eqn.resAA).keys()
				sort(keymat,(1::cols(keymat))')
			}
		}
		else if (vname=="") {
			// no vname means extract from the model struct estAA. 2 keys.
			if (classname((d.estAA).get((key1,key2)))=="AssociativeArray")  {
				// AA with estimation results, 2 subkeys or return the AA
				AA = (d.estAA).get((key1,key2))
				if ((subkey1+subkey2)=="") {
					return(AA)
				}
				else {
					return(AA.get((subkey1,subkey2)))
				}
			}
			else {
				// not an AA, or AA but no subkeys
				return((d.estAA).get((key1,key2)))
			}
		}
		else {
			// vname is in either nameY, nameD or nameZ
			eqn = (d.eqnAA).get(vname)
			if ((key1+key2)=="") {
				// no keys, return eqn
				return(eqn)
			}
			else if (key3=="") {
				// only 2 keys, it's lrnAA
				return((eqn.lrnAA).get((key1,key2)))
			}
			else {
				// 3 keys, it's resAA		
				return((eqn.resAA).get((key1,key2,key3)))
			}
		}
		
	}
	
}

void display_mse(												///
									struct mStruct d,			///
									string scalar show,			///
									string matrix reqn,			///
									string matrix rvtilde,		///
									real matrix DZeq01,			///
									real matrix rsmp,			///
									real matrix rmatmse,		///
									real matrix rmatmse_folds	///
									)
{
	
	if ((rows(DZeq01)>0) & (d.model=="interactive")) {
		// interactive
		DZeq01text = "D="
	}		
	else if (rows(DZeq01)>0) {
		// LATE
		DZeq01text = "Z="
	}
	else {
		// all others
		DZeq01text = ""
	}
	
	if (show=="MSE") {
		fmt = "{res}%10.3f  "
	}
	else {
		fmt = "{res}%10.0f  "
	}


	printf("\n{txt}MSEs for %s:\n",reqn[1])
	printf("{txt}{space 16}")
	if (DZeq01text~="") {
		printf("{txt}%2s ", DZeq01text)
	}
	printf("{txt}%4s ","rep")
	printf("{txt}%10s ","full smp")
	for (j=1; j<=cols(rmatmse_folds);j++) {
		printf("{txt} %10s ", "fold "+strofreal(j))
	}
	printf("\n")
	for (i=1;i<=rows(rvtilde);i++) {
		printf("{txt}%13s", rvtilde[i])
		printf("{txt}{space 3}")
		if (DZeq01text~="") {
			printf("{res}%2.0f ", DZeq01[i])
		}
		printf("{res}%4.0f ", rsmp[i])
		printf(fmt, rmatmse[i])
		for (j=1; j<=cols(rmatmse_folds);j++) {
			printf(fmt, rmatmse_folds[i,j])
		}
		printf("\n")
	}
}

void display_pystacked_weights(									///
									struct mStruct d,			///
									string scalar vname,		///
									string scalar rname,		///
									real matrix rmat,			///
									string matrix base_est,		///
									string scalar DZeq01			///
									)
{

	struct eStruct scalar eqn
	class AssociativeArray scalar AA
	
	// assemble message
	if (d.model=="interactive") {
		if (d.nameY==vname) {
			condit = "X,D="+DZeq01
		}
		else {
			condit = "X"
		}
	}
	else if (d.model=="late") {
		if ((d.nameY==vname) | (d.nameZ==vname)) {
			condit = "X"
		}
		else {
			condit = "X,Z="+DZeq01
		}
	}
	else if (d.model=="ivhd") {
		condit = "X,Z"
	}
	else {
		condit = "X"
	}
	
	printf("\n{txt}pystacked weights for E[%s|%s] = %s, resample %s:\n",	///
		vname,																///
		condit,																///
		substr(rname,1,strrpos(rname,"_")-1),								///
		substr(rname,strrpos(rname,"_")+1))
	printf("{txt}%12s","fold:")
	for (j=1;j<=cols(rmat);j++) {
		printf("{txt}    %-4.0f",j)
	}
	printf("\n")
	for (i=1;i<=rows(rmat);i++) {
		printf("{txt}%12s",base_est[i])
		for (j=1;j<=cols(rmat);j++) {
			printf("{res}%7.3f ",rmat[i,j])
		}
		printf("\n")
	}
	
}

end

