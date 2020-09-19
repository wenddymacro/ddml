## A simple Stata package for Double Debiased Machine Learning

This package implements the DDML estimator for the partial linear model. 
It's an early incomplete version; so please use with care. 

```
clear
use https://statalasso.github.io/dta/AJR.dta
   
net install ddml, from(https://raw.githubusercontent.com/aahrens1/ddml/master/)
   
set seed 123
ddml2 (lasso2 logpgp95 lat_abst edes1975 avelf temp* humid* steplow-oilres , lic(aicc) postres) ///
	      (lasso2 avexpr lat_abst edes1975 avelf temp* humid* steplow-oilres, lic(aicc) postres), /// 
	      kfolds(5) r tabf

ddml init partial
ddml yeq mylasso: (lasso2 logpgp95 lat_abst edes1975 avelf temp* humid* steplow-oilres, lic(aicc) postres)
ddml deq myforest: (lasso2 avexpr lat_abst edes1975 avelf temp* humid* steplow-oilres, lic(aicc) postres)
ddml deq myrlasso: (rlasso avexpr lat_abst edes1975 avelf temp* humid* steplow-oilres)
ddml crossfit, kfolds(5)
ddml estimate
```
