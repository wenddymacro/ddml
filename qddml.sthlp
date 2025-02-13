{smcl}
{* *! version 23aug2022}{...}
{hline}
{cmd:help ddml}{right: v0.5}
{hline}

{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{hi: qddml} {hline 2}}Stata program for Double Debiased Machine Learning{p_end}
{p2colreset}{...}

{pstd}
{opt ddml} implements algorithms for causal inference aided by supervised
machine learning as proposed in 
{it:Double/debiased machine learning for treatment and structural parameters}
(Econometrics Journal, 2018). Five different models are supported, allowing for 
binary or continous treatment variables and endogeneity, high-dimensional 
controls and/or instrumental variables. 
{opt ddml} supports a variety of different ML programs, including
but not limited to {helpb lassopack} and {helpb pystacked}. 

{pstd}
{opt qddml} is a wrapper program of {cmd:ddml}. It provides a convenient 
one-line syntax with almost the full flexibility of {cmd:ddml}.
The main restriction of {cmd:qddml} is that it only allows to be used 
with one machine learning program at the time, while {cmd:ddml} 
allow for multiple learners per reduced form equation.

{pstd}
{opt qddml} uses stacking regression ({helpb pystacked}) 
as the default machine learning program. 

{pstd}
{opt qddml} relies on {helpb crossfit}, which can be used as a standalone
program.

{p 8 14 2}
{cmd:qddml}
{it:depvar} {it:regressors} [{cmd:(}{it:hd_controls}{cmd:)}]
{cmd:(}{it:endog}{cmd:=}{it:instruments}{cmd:)}
[{cmd:if} {it:exp}] [{cmd:in} {it:range}]
{opt model(name)}
{bind:[ {cmd:,}}
{opt cmd(string)}
{opt cmdopt(string)}
{opt mname(string)}
{opt noreg}
{opt ...} ]}

{pstd}
Since {opt qddml} uses {helpb pystacked} per default, 
it requires Stata 16 or higher, Python 3.x and at least scikit-learn 0.24. See 
{helpb python:this help file}, {browse "https://blog.stata.com/2020/08/18/stata-python-integration-part-1-setting-up-stata-to-use-python/":this Stata blog entry}
and 
{browse "https://www.youtube.com/watch?v=4WxMAGNhcuE":this Youtube video}
for how to set up
Python on your system.
In short, install Python 3.x (we recommend Anaconda) 
and set the appropriate Python path using {cmd:python set exec}.
If you don't have Stata 16+,
you can still use {cmd:pystacked} with programs that don't rely on Python, 
e.g., using the option {opt cmd(rlasso)}.

{pstd}
Please check the {helpb qddml##examples:examples} provided at the end of the help file.

{marker syntax}{...}
{title:Options}

{synoptset 20}{...}
{synopthdr:General}
{synoptline}
{synopt:{opt model(name)}}
the model to be estimated; allows for {it:partial}, {it:interactive},
{it:iv}, {it:ivhd}, {it:late}. See {helpb ddml##models:here} for an overview.
{p_end}
{synopt:{opt mname(string)}}
name of the DDML model. Allows to run multiple DDML
models simultaneously. Defaults to {it:m0}.
{p_end}
{synopt:{opt kfolds(integer)}}
number of cross-fitting folds. The default is 5.
{p_end}
{synopt:{opt fcluster(varname)}}
cluster identifiers for cluster randomization of random folds.
{p_end}
{synopt:{opt foldvar(varname)}}
integer variable with user-specified cross-fitting folds.
{p_end}
{synopt:{opt reps(integer)}}
number of re-sampling iterations, i.e., how often the cross-fitting procedure is
repeated on randomly generated folds. 
{p_end}
{synopt:{opt shortstack}} asks for short-stacking to be used.
Short-stacking runs contrained non-negative least squares on the
cross-fitted predicted values to obtain a weighted average
of several base learners.
{p_end}
{synopt:{cmdab:r:obust}}
report SEs that are robust to the
presence of arbitrary heteroskedasticity.
{p_end}
{synopt:{opt vce(type)}}
select variance-covariance estimator, see {helpb regress##vcetype:here}
{p_end}
{synopt:{opt cluster(varname)}}
select cluster-robust variance-covariance estimator.
{p_end}
{synopt:{opt noreg}}
do not add {helpb regress} as an additional learner. 
{p_end}

{synoptset 20}{...}
{synopthdr:Learners}
{synoptline}
{synopt:{opt cmd(string)}}
ML program used for estimating conditional expectations. 
Defaults to {helpb pystacked}. 
See {helpb ddml##compatibility:here} for 
other supported programs.
{p_end}
{synopt:{opt ycmd(string)}}
ML program used for estimating the conditional expectations of the outcome {it:Y}. 
Defaults to {opt cmd(string)}. 
{p_end}
{synopt:{opt dcmd(string)}}
ML program used for estimating the conditional expectations of the treatment variable(s) {it:D}. 
Defaults to {opt cmd(string)}. 
{p_end}
{synopt:{opt zcmd(string)}}
ML program used for estimating conditional expectations of instrumental variable(s) {it:Z}. 
Defaults to {opt cmd(string)}. 
{p_end}
{synopt:{opt *cmdopt(string)}}
options that are passed on to ML program. 
The asterisk {cmd:*} can be replaced with either nothing 
(setting the default for all reduced form equations), 
{cmd:y} (setting the default for the conditional expectation of {it:Y}), 
{cmd:d} (setting the default for {it:D})
or {cmd:z} (setting the default for {it:Z}).
{p_end}
{synopt:{opt *vtype(string)}}
variable type of the variable to be created. Defaults to {it:double}. 
{it:none} can be used to leave the type field blank 
(this is required when using {cmd:ddml} with {helpb rforest}.)
The asterisk {cmd:*} can be replaced with either nothing 
(setting the default for all reduced form equations), 
{cmd:y} (setting the default for the conditional expectation of {it:Y}), 
{cmd:d} (setting the default for {it:D})
or {cmd:z} (setting the default for {it:Z}).
{p_end}
{synopt:{opt *predopt(string)}}
{cmd:predict} option to be used to get predicted values. 
Typical values could be {opt xb} or {opt pr}. Default is 
blank. The asterisk {cmd:*} can be replaced with either nothing 
(setting the default for all reduced form equations), 
{cmd:y} (setting the default for the conditional expectation of {it:Y}), 
{cmd:d} (setting the default for {it:D})
or {cmd:z} (setting the default for {it:Z}).
{p_end}

{synoptset 20}{...}
{synopthdr:Output}
{synoptline}
{synopt:{opt verb:ose}}
show detailed output
{p_end}
{synopt:{opt vverb:ose}}
show even more output
{p_end}

{marker models}{...}
{title:Models}

{pstd} 
See {helpb ddml##models:here}.

{marker compatibility}{...}
{title:Compatible programs}

{pstd} 
See {helpb ddml##compatibility:here}.

{marker examples}{...}
{title:Examples}

{pstd}
Below we demonstrate the use of {cmd:qddml} for each of the 5 models supported. 
Note that estimation models are chosen for demonstration purposes only and 
kept simple to allow you to run the code quickly.
Please also see the examples in the {helpb ddml##examples:ddml help file}

{pstd}{ul:Partially linear model.} 

{pstd}Preparations: we load the data, define global macros and set the seed.{p_end}
{phang2}. {stata "use https://github.com/aahrens1/ddml/raw/master/data/sipp1991.dta, clear"}{p_end}
{phang2}. {stata "global Y net_tfa"}{p_end}
{phang2}. {stata "global D e401"}{p_end}
{phang2}. {stata "global X tw age inc fsize educ db marr twoearn pira hown"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}

{pstd}The options {cmd:model(partial)} selects the partially linear model
and {cmd:kfolds(2)} selects two cross-fitting folds.
We use the options {cmd:cmd()} and {cmd:cmdopt()} to select
random forest for estimating the conditional expectations.{p_end}

{pstd}Note that we set the number of random folds to 2, so that 
the model runs quickly. The default is {opt kfolds(5)}. We recommend 
to consider at least 5-10 folds and even more if your sample size is small.{p_end}

{pstd}Note also that we recommend to re-run the model multiple time on 
different random folds, see options {opt reps(integer)}.{p_end}

{phang2}. {stata "qddml $Y $D ($X), kfolds(2) model(partial) cmd(pystacked) cmdopt(type(reg) method(rf))"}{p_end}

{pstd}{ul:Partially linear IV model.} 

{pstd}Preparations: we load the data, define global macros and set the seed.{p_end}
{phang2}. {stata "use https://statalasso.github.io/dta/AJR.dta, clear"}{p_end}
{phang2}. {stata "global Y logpgp95"}{p_end}
{phang2}. {stata "global D avexpr"}{p_end}
{phang2}. {stata "global Z logem4"}{p_end}
{phang2}. {stata "global X lat_abst edes1975 avelf temp* humid* steplow-oilres"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}

{pstd}Since the
data set is very small, we consider 30 cross-fitting folds.{p_end} 
{pstd}We need to add the option {opt vtype(none)} for {helpb rforest} to 
work with {cmd:ddml} since {helpb rforests}'s {cmd:predict} command doesn't
support variable types.{p_end}

{phang2}. {stata "qddml $Y ($X) ($D=$Z), kfolds(30) model(iv) cmd(rforest) cmdopt(type(reg)) vtype(none) robust"}{p_end}

{pstd}{ul:Interactive model--ATE and ATET estimation.} 

{pstd}Preparations: we load the data, define global macros and set the seed.{p_end}
{phang2}. {stata "webuse cattaneo2, clear"}{p_end}
{phang2}. {stata "global Y bweight"}{p_end}
{phang2}. {stata "global D mbsmoke"}{p_end}
{phang2}. {stata "global X mage prenatal1 mmarried fbaby mage medu"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}

{pstd}
Note that we use gradient boosted regression trees for E[Y|X,D] (see {opt ycmdopt()}),
but gradient boosted classification trees for E[D|X] (see {opt dcmdopt()}).
{p_end} 
{phang2}. {stata "qddml $Y $D ($X), kfolds(5) reps(5) model(interactive) cmd(pystacked) ycmdopt(type(reg) method(gradboost)) dcmdopt(type(class) method(gradboost))"}{p_end}

{pstd}{cmd:qddml} reports the ATE effect by default. The option {cmd:atet}
returns the ATET estimate.{p_end}

{pstd}If we want retrieve the ATET estimate after estimation, 
we can simply use {ddml estimate}.{p_end}
{phang2}. {stata "ddml estimate, atet"}{p_end}

{pstd}{ul:Interactive IV model--LATE estimation.} 

{pstd}Preparations: we load the data, define global macros and set the seed.{p_end}
{phang2}. {stata "use http://fmwww.bc.edu/repec/bocode/j/jtpa.dta,clear"}{p_end}
{phang2}. {stata "global Y earnings"}{p_end}
{phang2}. {stata "global D training"}{p_end}
{phang2}. {stata "global Z assignmt"}{p_end}
{phang2}. {stata "global X sex age married black hispanic"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}

{phang2}. {stata "qddml $Y (c.($X)# #c($X)) ($D=$Z), kfolds(5) model(interactiveiv) cmd(pystacked) ycmdopt(type(reg) m(lassocv)) dcmdopt(type(class) m(lassocv)) zcmdopt(type(class) m(lassocv))"}{p_end}

{pstd}{ul:High-dimensional IV model.} 

{pstd}Preparations: we load the data, define global macros and set the seed.{p_end}
{phang2}. {stata "use https://github.com/aahrens1/ddml/raw/master/data/BLP.dta, clear"}{p_end}
{phang2}. {stata "global Y share"}{p_end}
{phang2}. {stata "global D price"}{p_end}
{phang2}. {stata "global X hpwt air mpd space"}{p_end}
{phang2}. {stata "global Z sum*"}{p_end}
{phang2}. {stata "set seed 42"}{p_end}

{pstd}The syntax is the same as in the partially linear IV model, 
but we now allow for high-dimensional instruments.{p_end}
{phang2}. {stata "qddml $Y ($X) ($D=$Z), model(ivhd)"}{p_end}

{marker references}{title:References}

{pstd}
Chernozhukov, V., Chetverikov, D., Demirer, M., 
Duflo, E., Hansen, C., Newey, W. and Robins, J. (2018), 
Double/debiased machine learning for 
treatment and structural parameters. 
{it:The Econometrics Journal}, 21: C1-C68. {browse "https://doi.org/10.1111/ectj.12097"}

{marker installation}{title:Installation}

{pstd}
To get the latest stable version of {cmd:ddml} from our website, 
check the installation instructions at {browse "https://statalasso.github.io/installation/"}.
We update the stable website version more frequently than the SSC version.

{pstd}
To verify that {cmd:ddml} is correctly installed, 
click on or type {stata "whichpkg ddml"} 
(which requires {helpb whichpkg} 
to be installed; {stata "ssc install whichpkg"}).

{title:Authors}

{pstd}
Achim Ahrens, Public Policy Group, ETH Zurich, Switzerland  {break}
achim.ahrens@gess.ethz.ch

{pstd}
Christian B. Hansen, University of Chicago, USA {break}
Christian.Hansen@chicagobooth.edu

{pstd}
Mark E Schaffer, Heriot-Watt University, UK {break}
m.e.schaffer@hw.ac.uk   

{pstd}
Thomas Wiemann, University of Chicago, USA {break}
wiemann@uchicago.edu

{title:Also see (if installed)}

{pstd}
Help: {helpb lasso2}, {helpb cvlasso}, {helpb rlasso}, {helpb ivlasso},
 {helpb pdslasso}, {helpb pystacked}.{p_end}
