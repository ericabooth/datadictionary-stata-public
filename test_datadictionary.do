* ===========================================================================
* test_datadictionary.do -- test battery for datadictionary v1.0.0
* Run in batch from the package directory:
*     stata-mp -b do test_datadictionary.do
* Judge the run by the log: no r(NNN) errors, no "assertion is false".
* ---------------------------------------------------------------------------
* All paths live in globals set in this header (the package will move to its
* own repo; edit $pkgroot only).  Excel outputs land in the package folder
* (covered by .gitignore); every .dta goes to a temp directory, never the
* repo folder.
* ===========================================================================
global pkgroot "/Users/ebooth/Documents/GitHub/Book Manuscript:Applied Evaluation-Stata/datadictionary-stata-public"
global ddout   "$pkgroot"

version 16.0
clear all
set more off
set seed 20260714
adopath + "$pkgroot"

* temp directory for the synthetic wave files and all .dta outputs
global ddtmp "`c(tmpdir)'"
if substr("$ddtmp", -1, .) != "/" global ddtmp "$ddtmp/"
global ddtmp "${ddtmp}datadictionary_test"
capture mkdir "$ddtmp"

* ---------------------------------------------------------------------------
* 0. Synthetic longitudinal staff-wellbeing survey: THREE separate wave
*    files.  This is the demo dataset promised in the book chapter.
*      wave 1 (2019, N=180): id q1-q5 (q2 on 4-pt agree4), occupation
*                            (string with typo variants), hours (~8% miss)
*      wave 2 (2021, N=210): drops q4, adds q6 (burnout), hours ~15% miss
*      wave 3 (2023, N=195): q2 RECODED to 5-pt agree5 (categories added and
*                            relabeled), q6 retained, adds q7, q1 label
*                            reworded
* ---------------------------------------------------------------------------

* ---- wave 1 (2019) ----
clear
set obs 180
gen int id = _n
gen byte q1 = runiformint(1, 5)
label variable q1 "Overall job satisfaction (1-5)"
label define agree4 1 "Strongly disagree" 2 "Disagree" 3 "Agree" 4 "Strongly agree"
gen byte q2 = runiformint(1, 4)
label values q2 agree4
label variable q2 "I feel supported by my supervisor"
label define yesno 0 "No" 1 "Yes"
gen byte q3 = runiformint(0, 1)
label values q3 yesno
label variable q3 "Considered leaving job in past year"
gen byte q4 = runiformint(1, 4)
label values q4 agree4
label variable q4 "My workload is manageable"
gen byte q5 = runiformint(1, 10)
label variable q5 "Self-rated wellbeing (1-10)"
gen byte _oc = runiformint(1, 6)
gen str9 occupation = cond(_oc == 1, "Teacher",              ///
    cond(_oc == 2, "teacher", cond(_oc == 3, "Nurse",        ///
    cond(_oc == 4, "nurse", cond(_oc == 5, "Admin", "Counselor")))))
drop _oc
label variable occupation "Occupation (free text)"
gen hours = round(rnormal(42, 6), .5)
replace hours = . if runiform() < .08
format hours %5.1f
label variable hours "Weekly work hours (self-report)"
note q2: Core supervisor-support item; fielded every wave.
note hours: Self-reported average weekly hours.
char q2[srctag] "staff_survey_w1.dta"
char hours[srctag] "staff_survey_w1.dta"
char q2[module] "core"
label data "Staff wellbeing survey, wave 1 (2019)"
save "$ddtmp/staff_survey_w1.dta", replace

* ---- wave 2 (2021): q4 dropped, q6 added, pandemic missingness in hours ----
clear
set obs 210
gen int id = _n
gen byte q1 = runiformint(1, 5)
label variable q1 "Overall job satisfaction (1-5)"
label define agree4 1 "Strongly disagree" 2 "Disagree" 3 "Agree" 4 "Strongly agree"
gen byte q2 = runiformint(1, 4)
label values q2 agree4
label variable q2 "I feel supported by my supervisor"
label define yesno 0 "No" 1 "Yes"
gen byte q3 = runiformint(0, 1)
label values q3 yesno
label variable q3 "Considered leaving job in past year"
gen byte q5 = runiformint(1, 10)
label variable q5 "Self-rated wellbeing (1-10)"
gen byte q6 = runiformint(1, 4)
label values q6 agree4
label variable q6 "I feel burned out at work"
gen byte _oc = runiformint(1, 6)
gen str9 occupation = cond(_oc == 1, "Teacher",              ///
    cond(_oc == 2, "teacher", cond(_oc == 3, "Nurse",        ///
    cond(_oc == 4, "nurse", cond(_oc == 5, "Admin", "Counselor")))))
drop _oc
label variable occupation "Occupation (free text)"
gen hours = round(rnormal(41, 7), .5)
replace hours = . if runiform() < .15
format hours %5.1f
label variable hours "Weekly work hours (self-report)"
note q2: Core supervisor-support item; fielded every wave.
note hours: Self-reported average weekly hours.
char q2[srctag] "staff_survey_w2.dta"
char hours[srctag] "staff_survey_w2.dta"
char q2[module] "core"
label data "Staff wellbeing survey, wave 2 (2021)"
save "$ddtmp/staff_survey_w2.dta", replace

* ---- wave 3 (2023): q2 recoded to 5-pt agree5, q7 added, q1 reworded ----
clear
set obs 195
gen int id = _n
gen byte q1 = runiformint(1, 5)
label variable q1 "Overall satisfaction with job (1-5 scale)"
label define agree5 1 "Strongly disagree" 2 "Somewhat disagree" ///
    3 "Neither agree nor disagree" 4 "Somewhat agree" 5 "Strongly agree"
gen byte q2 = runiformint(1, 5)
label values q2 agree5
label variable q2 "I feel supported by my supervisor"
label define yesno 0 "No" 1 "Yes"
gen byte q3 = runiformint(0, 1)
label values q3 yesno
label variable q3 "Considered leaving job in past year"
gen byte q5 = runiformint(1, 10)
label variable q5 "Self-rated wellbeing (1-10)"
label define agree4 1 "Strongly disagree" 2 "Disagree" 3 "Agree" 4 "Strongly agree"
gen byte q6 = runiformint(1, 4)
label values q6 agree4
label variable q6 "I feel burned out at work"
gen byte q7 = runiformint(0, 1)
label values q7 yesno
label variable q7 "Would recommend this workplace to others"
gen byte _oc = runiformint(1, 6)
gen str9 occupation = cond(_oc == 1, "Teacher",              ///
    cond(_oc == 2, "teacher", cond(_oc == 3, "Nurse",        ///
    cond(_oc == 4, "nurse", cond(_oc == 5, "Admin", "Counselor")))))
drop _oc
label variable occupation "Occupation (free text)"
gen hours = round(rnormal(42, 6), .5)
replace hours = . if runiform() < .10
format hours %5.1f
label variable hours "Weekly work hours (self-report)"
note q2: Recoded from 4-point (agree4) to 5-point (agree5) in 2023.
note hours: Self-reported average weekly hours.
char q2[srctag] "staff_survey_w3.dta"
char hours[srctag] "staff_survey_w3.dta"
char q2[module] "core"
label data "Staff wellbeing survey, wave 3 (2023)"
save "$ddtmp/staff_survey_w3.dta", replace

* memory now holds wave 3; battery 1 must preserve and restore it untouched

* ---------------------------------------------------------------------------
* 1. Files mode over the three waves: r() results, change detection,
*    saving() .dta content, and preserve/restore of the caller's data
* ---------------------------------------------------------------------------
datadictionary, files("$ddtmp/staff_survey_w1.dta $ddtmp/staff_survey_w2.dta $ddtmp/staff_survey_w3.dta") ///
    wavenames("2019 2021 2023")                       ///
    excel("$ddout/datadictionary_staffsurvey.xlsx")         ///
    saving("$ddtmp/datadictionary_codebook.dta") replace
local NV = r(nvars)
local NC = r(nchanges)
local XL `"`r(xlsx)'"'
local DT `"`r(dta)'"'

* 8 + 8 + 9 variable-wave rows
assert `NV' == 25
assert `NC' >= 5
assert `"`XL'"' == "$ddout/datadictionary_staffsurvey.xlsx"
assert `"`DT'"' == "$ddtmp/datadictionary_codebook.dta"

* the caller's data (wave 3) came back untouched
assert _N == 195
assert c(k) == 9
assert id[1] == 1

* --- the Changes output detects the five planted changes ---
import excel using `"`XL'"', sheet("Changes") firstrow clear
assert _N == `NC'
quietly count if name == "q4" & change == "variable dropped" & wavepair == "2019 -> 2021"
assert r(N) == 1
quietly count if name == "q6" & change == "variable added" & wavepair == "2019 -> 2021"
assert r(N) == 1
quietly count if name == "q7" & change == "variable added" & wavepair == "2021 -> 2023"
assert r(N) == 1
quietly count if name == "q1" & change == "variable label changed" & wavepair == "2021 -> 2023"
assert r(N) == 1
quietly count if name == "q2" & change == "value label set changed" & wavepair == "2021 -> 2023"
assert r(N) == 1
* before/after carry the label-set signatures
quietly count if name == "q2" & strpos(before, "agree4") & strpos(after, "agree5") ///
    & strpos(after, "Somewhat agree")
assert r(N) == 1
* q1's label change carries the old and new wording
quietly count if name == "q1" & before == "Overall job satisfaction (1-5)" ///
    & after == "Overall satisfaction with job (1-5 scale)"
assert r(N) == 1

* --- the saving() dta: one row per variable-wave, srctag harvested ---
use "$ddtmp/datadictionary_codebook.dta", clear
assert _N == 25
quietly count if wave == "2019"
assert r(N) == 8
quietly count if wave == "2021"
assert r(N) == 8
quietly count if wave == "2023"
assert r(N) == 9
quietly count if name == "q2" & srctag != ""
assert r(N) == 3
assert srctag == "staff_survey_w1.dta" if name == "q2" & wave == "2019"
assert srctag == "staff_survey_w3.dta" if name == "q2" & wave == "2023"
assert vallab == "agree4" if name == "q2" & wave != "2023"
assert vallab == "agree5" if name == "q2" & wave == "2023"
assert notes != "" if name == "q2"
assert strpos(chars, "module=core") if name == "q2"
assert n == 180 if name == "id" & wave == "2019"
assert n == 210 if name == "id" & wave == "2021"
assert n == 195 if name == "id" & wave == "2023"
* numeric stats populated for numerics, blank for strings
assert !missing(mean) if name == "hours"
assert missing(mean) & missing(sd) if name == "occupation"
assert examples != "" if name == "occupation" | name == "q2"
* the "changed since previous wave" flag: q1's label reworded and q2's
* value-label set replaced, both in 2023; everything else blank
assert changed == "label"      if name == "q1" & wave == "2023"
assert changed == "categories" if name == "q2" & wave == "2023"
assert changed == "" if name == "q1" & wave == "2019"
assert changed == "" if name == "q2" & wave == "2021"
assert changed == "" if name == "id"                       // never changes

* ---------------------------------------------------------------------------
* 1b. folder()/pattern() mode: same waves, same answers
* ---------------------------------------------------------------------------
datadictionary, folder("$ddtmp") pattern("staff_survey_w*.dta") ///
    wavenames("2019 2021 2023")
assert r(nvars) == 25
assert r(nchanges) == `NC'

* ---------------------------------------------------------------------------
* 2. Round-trip: import the Excel Variables sheet back
* ---------------------------------------------------------------------------
import excel using `"`XL'"', sheet("Variables") firstrow clear
capture confirm string variable wave
if _rc tostring wave, replace
assert _N == 25
assert vallab == "agree5" if name == "q2" & wave == "2023"
assert vallab == "agree4" if name == "q2" & wave == "2019"
assert type == "str9" if name == "occupation" & wave == "2019"

* ---------------------------------------------------------------------------
* 3. In-memory mode on the stitched long file, with wave()
* ---------------------------------------------------------------------------
use "$ddtmp/staff_survey_w1.dta", clear
gen int wave = 2019
append using "$ddtmp/staff_survey_w2.dta"
replace wave = 2021 if missing(wave)
append using "$ddtmp/staff_survey_w3.dta"
replace wave = 2023 if missing(wave)
label variable wave "Survey wave (year)"
assert _N == 585

datadictionary, wave(wave) excel("$ddout/datadictionary_stitched.xlsx") ///
    saving("$ddtmp/dd_stitched.dta") replace
* 10 data variables (the wave identifier is excluded) x 3 waves = 30 rows
assert r(nvars) == 30
assert r(nchanges) == 0
assert `"`r(xlsx)'"' == "$ddout/datadictionary_stitched.xlsx"
* the stitched data came back untouched
assert _N == 585
assert c(k) == 11

* Missingness now lives INSIDE the Variables sheet as the pctmiss column, one
* row per variable-wave; there is no separate Missingness sheet.  A variable
* absent in a wave (dropped, or not yet fielded) shows 100% missing that wave.
use "$ddtmp/dd_stitched.dta", clear
assert _N == 30
capture confirm string variable wave
if _rc tostring wave, replace
assert pctmiss <  100 if name == "q4" & wave == "2019"
assert pctmiss == 100 if name == "q4" & wave == "2021"
assert pctmiss == 100 if name == "q4" & wave == "2023"
assert pctmiss == 100 if name == "q6" & wave == "2019"
assert pctmiss <  100 if name == "q6" & wave == "2021"
assert pctmiss == 100 if name == "q7" & wave == "2019"
assert pctmiss == 100 if name == "q7" & wave == "2021"
assert pctmiss <  100 if name == "q7" & wave == "2023"
quietly count if name == "hours" & pctmiss < 100
assert r(N) == 3
* the wave identifier is not documented as a data column
quietly count if name == "wave"
assert r(N) == 0
* in-memory wave mode cannot detect label changes, so changed is always blank
quietly count if changed != ""
assert r(N) == 0
* no separate Missingness sheet is written
import excel using "$ddout/datadictionary_stitched.xlsx", describe
local hasmiss 0
forvalues s = 1/`r(N_worksheet)' {
    if "`r(worksheet_`s')'" == "Missingness" local hasmiss 1
}
assert `hasmiss' == 0

* ---------------------------------------------------------------------------
* 3b. Relabel do-file and dictionary: the export / edit / re-import round-trip
*     (both are in-memory features; run on wave 1, which has value labels,
*      notes, and srctag/module chars)
* ---------------------------------------------------------------------------
cd "$ddtmp"
use "staff_survey_w1.dta", clear
datadictionary, dofile("w1_relabel.do") dictionary("w1.dct") replace
assert `"`r(dofile)'"' == "w1_relabel.do"
assert `"`r(dct)'"'    == "w1.dct"
confirm file "w1_relabel.do"
confirm file "w1.dct"

* --- do-file round-trip: strip labels via CSV, rename + add a column, relabel -
use "staff_survey_w1.dta", clear
export delimited using "w1.csv", nolabel replace
import delimited using "w1.csv", varnames(1) case(preserve) clear
rename q4 q4_manage                 // renamed -> flagged, never fuzzily relabeled
gen newcol = 1                      // added   -> flagged as extra
do "w1_relabel.do"
* variable label, value label, format-bearing chars, and notes restored
local ll2 : value label q2
assert "`ll2'" == "agree4"
local vl2 : variable label q2
assert `"`vl2'"' == "I feel supported by my supervisor"
local st : char q2[srctag]
assert "`st'" == "staff_survey_w1.dta"
local mod : char q2[module]
assert "`mod'" == "core"
local k0 : char q2[note0]
assert "`k0'" == "1"
* the renamed column must NOT have received q4's label (exact matching on)
local vlq4 : variable label q4_manage
assert `"`vlq4'"' == ""
* reproduce the receipt logic and assert the diagnostics it reports
local expected "id q1 q2 q3 q4 q5 occupation hours"
local missing ""
foreach v of local expected {
    capture confirm variable `v', exact
    if _rc local missing "`missing' `v'"
}
assert strtrim("`missing'") == "q4"
unab present : _all
local extra : list present - expected
assert "`extra'" == "q4_manage newcol"

* --- norecast: the generated file carries no -recast- lines -------------------
use "staff_survey_w1.dta", clear
datadictionary, dofile("w1_norecast.do") norecast replace
tempname fh
file open `fh' using "w1_norecast.do", read text
local nrecast 0
file read `fh' line
while r(eof) == 0 {
    if strpos(`"`macval(line)'"', "capture recast") local ++nrecast
    file read `fh' line
}
file close `fh'
assert `nrecast' == 0

* --- dictionary round-trip: tab-delimited quoted export, infile via .dct ------
use "staff_survey_w1.dta", clear
export delimited using "w1.txt", delimiter(tab) nolabel quote replace
infile using "w1.dct", clear
assert _N == 180
assert c(k) == 8
local tq2 : type q2
assert "`tq2'" == "byte"
local to : type occupation
assert substr("`to'", 1, 3) == "str"
local vlo : variable label occupation
assert `"`vlo'"' == "Occupation (free text)"
count if occupation == "Counselor"
assert r(N) > 0

* --- files mode rejects dofile()/dictionary() and norecast -------------------
capture datadictionary, files("staff_survey_w1.dta") dofile("x.do")
assert _rc == 198
capture datadictionary, files("staff_survey_w1.dta") dictionary("x.dct")
assert _rc == 198
capture datadictionary, files("staff_survey_w1.dta") norecast
assert _rc == 198

* ---------------------------------------------------------------------------
* 3c. Cross-sectional (non-wave) data: the simple case on sysuse auto.
*     One row per variable; % missing sits beside the statistics; no wave or
*     changed columns; three sheets only (Overview, Variables, ValueLabels).
* ---------------------------------------------------------------------------
sysuse auto, clear
datadictionary, excel("$ddtmp/dd_auto.xlsx") saving("$ddtmp/dd_auto.dta") replace
assert r(nvars) == 12
assert r(nchanges) == 0
use "$ddtmp/dd_auto.dta", clear
assert _N == 12
capture confirm variable wave
assert _rc != 0
capture confirm variable changed
assert _rc != 0
* rep78 has 5 missing of 74; price has none -> % missing computed inline
assert abs(pctmiss - 100*5/74) < 0.01 if name == "rep78"
assert pctmiss == 0 if name == "price"
* foreign carries its value label and its categories show up in examples
assert vallab == "origin" if name == "foreign"
assert strpos(examples, "Domestic") if name == "foreign"
import excel using "$ddtmp/dd_auto.xlsx", describe
assert r(N_worksheet) == 3

* ---------------------------------------------------------------------------
* 4. Edge cases: graceful errors and label-free data
* ---------------------------------------------------------------------------
* empty if/in selection -> clear message, rc 2000
sysuse auto, clear
capture datadictionary if price < 0
assert _rc == 2000

* excel() without replace on an existing file -> 602
datadictionary mpg, excel("$ddtmp/dd_exists.xlsx") replace
assert r(nvars) == 1
capture datadictionary mpg, excel("$ddtmp/dd_exists.xlsx")
assert _rc == 602

* saving() without replace on an existing file -> 602
datadictionary mpg, saving("$ddtmp/dd_s.dta") replace
capture datadictionary mpg, saving("$ddtmp/dd_s.dta")
assert _rc == 602

* a dataset with no value labels runs clean (header-only ValueLabels sheet)
clear
set obs 25
gen x = rnormal()
gen str8 s = "ab" + string(_n)
datadictionary, excel("$ddtmp/dd_novl.xlsx") saving("$ddtmp/dd_novl.dta") replace
assert r(nvars) == 2
assert r(nchanges) == 0

* empty memory, no files()/folder() -> rc 2000
clear
capture datadictionary
assert _rc == 2000

* option misuse -> 198 / 601
capture datadictionary, files("$ddtmp/staff_survey_w1.dta") folder("$ddtmp")
assert _rc == 198
sysuse auto, clear
capture datadictionary, wavenames("x")
assert _rc == 198
capture datadictionary, folder("$ddtmp") pattern("zzz*.dta")
assert _rc == 601
capture datadictionary, files("$ddtmp/does_not_exist.dta")
assert _rc == 601

* ---------------------------------------------------------------------------
* 5. Summary block: the key numbers for the book's worked example
* ---------------------------------------------------------------------------
di as res _n "==================== DATADICT TEST SUMMARY ===================="
di as txt "Per-wave N and variable counts:"
di as txt "  2019: N=180, vars=8   2021: N=210, vars=8   2023: N=195, vars=9"
di as txt "Files mode: r_nvars = " as res `NV' as txt "   r_nchanges = " as res `NC'

use "$ddtmp/datadictionary_codebook.dta", clear
di as txt "hours, % missing by wave:"
foreach w in 2019 2021 2023 {
    quietly summarize pctmiss if name == "hours" & wave == "`w'", meanonly
    di as txt "  `w': " as res %4.1f r(mean) as txt " %"
}
gen long _row = _n
foreach w in 2019 2023 {
    quietly summarize _row if name == "q2" & wave == "`w'", meanonly
    local e = examples[r(min)]
    di as txt "q2 top categories (`w'): " as res `"`e'"'
}

import excel using "$ddout/datadictionary_staffsurvey.xlsx", sheet("Changes") firstrow clear
di as txt "Changes detected (as datadictionary reports them):"
forvalues r = 1/`=_N' {
    di as txt "  " wavepair[`r'] " | " name[`r'] " | " change[`r']
}
di as txt "xlsx: $ddout/datadictionary_staffsurvey.xlsx  (and datadictionary_stitched.xlsx)"
di as txt "dta:  $ddtmp/datadictionary_codebook.dta"
di as res "==============================================================="

di as res _n "test_datadictionary.do: ALL TESTS PASSED"
