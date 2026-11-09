*! version 1.0.2  09nov2026  Eric A. Booth, Sr Researcher, Texas 2036
*! datadictionary: enhanced, over-time-ready codebook generator (a modern descsave)
*! 1.0.1: labels, notes, chars, value-label text, and string values that
*!        contain $ or a backtick are carried verbatim (macval) instead of
*!        being macro-expanded, and the relabel do-file escapes them.
*! 1.0.2: works when the temp folder path has a space (tempfiles quoted);
*!        the srctag column reads char[source], the stamp srctag, combineall
*!        and projectbuilder write; the round-trip recipe exports with quote
*!        and imports with bindquote(strict), so text with line breaks keeps
*!        its rows; open links expand a leading ~ and treat \ paths as
*!        absolute; wave and file basenames split on \ as well as /; an empty
*!        dataset (0 observations) is refused with its own message.
*
*  version 16.0 is the floor the package is tested against; no feature above
*  that baseline is required.  The caller's data are preserved and restored
*  untouched in both modes (restore happens automatically at program exit).

program define datadictionary, rclass
    version 16.0

    syntax [varlist(default=none)] [if] [in] [,          ///
        WAve(varname) FILes(string) FOLder(string)       ///
        PATtern(string) WAVENames(string)                ///
        EXcel(string) SAVing(string) REPlace             ///
        DOfile(string) DICTionary(string) NORECast       ///
        EXAMples(integer 3) TOP(integer 5)               ///
        NOCHars NONotes FLOW(string) ]

    * ---- option validation ---------------------------------------------------
    if `examples' < 1 {
        di as err "examples() must be a positive integer"
        exit 198
    }
    if `top' < 1 {
        di as err "top() must be a positive integer"
        exit 198
    }
    if `"`files'"' != "" & `"`folder'"' != "" {
        di as err "files() and folder() may not be combined; use one or the other"
        exit 198
    }
    if `"`pattern'"' != "" & `"`folder'"' == "" {
        di as err "pattern() requires folder()"
        exit 198
    }
    local filesmode = (`"`files'"' != "" | `"`folder'"' != "")
    if !`filesmode' & `"`wavenames'"' != "" {
        di as err "wavenames() applies to files mode only; specify files() or folder()"
        exit 198
    }
    if `filesmode' {
        if "`wave'" != "" {
            di as err "wave() applies to in-memory mode only; in files mode each file is a wave (name them with wavenames())"
            exit 198
        }
        if `"`if'`in'"' != "" | "`varlist'" != "" {
            di as err "varlist, if, and in apply to in-memory mode only"
            exit 198
        }
        if `"`dofile'"' != "" | `"`dictionary'"' != "" {
            di as err "dofile() and dictionary() describe a single dataset and run in in-memory mode only; load one wave and run datadictionary without files()/folder()"
            exit 198
        }
    }
    if `filesmode' & "`norecast'" != "" {
        di as err "norecast applies to dofile() only"
        exit 198
    }

    * ---- output file names, checked before any work ---------------------------
    if `"`excel'"' != "" {
        if lower(substr(`"`excel'"', -5, .)) != ".xlsx" local excel `"`excel'.xlsx"'
        if "`replace'" == "" {
            capture confirm new file `"`excel'"'
            if _rc {
                di as err `"excel file `excel' already exists; specify the replace option"'
                exit 602
            }
        }
    }
    if `"`saving'"' != "" {
        if lower(substr(`"`saving'"', -4, .)) != ".dta" local saving `"`saving'.dta"'
        if "`replace'" == "" {
            capture confirm new file `"`saving'"'
            if _rc {
                di as err `"saving file `saving' already exists; specify the replace option"'
                exit 602
            }
        }
    }
    if `"`dofile'"' != "" {
        if lower(substr(`"`dofile'"', -3, .)) != ".do" local dofile `"`dofile'.do"'
        if "`replace'" == "" {
            capture confirm new file `"`dofile'"'
            if _rc {
                di as err `"dofile `dofile' already exists; specify the replace option"'
                exit 602
            }
        }
    }
    if `"`dictionary'"' != "" {
        if lower(substr(`"`dictionary'"', -4, .)) != ".dct" local dictionary `"`dictionary'.dct"'
        if "`replace'" == "" {
            capture confirm new file `"`dictionary'"'
            if _rc {
                di as err `"dictionary `dictionary' already exists; specify the replace option"'
                exit 602
            }
        }
    }

    if `"`flow'"' != "" {
        capture confirm file `"`flow'"'
        if _rc {
            di as err `"flow file `flow' not found"'
            exit 601
        }
    }

    * ---- resolve the file list (files mode) ------------------------------------
    local nfiles 0
    if `"`folder'"' != "" {
        if `"`pattern'"' == "" local pattern "*.dta"
        if substr(`"`folder'"', -1, .) == "/" {
            local folder = substr(`"`folder'"', 1, strlen(`"`folder'"') - 1)
        }
        local fnames : dir `"`folder'"' files `"`pattern'"'
        local fnames : list sort fnames
        foreach f of local fnames {
            local ++nfiles
            local file`nfiles' `"`folder'/`f'"'
        }
        if `nfiles' == 0 {
            di as err `"no files in folder(`folder') match pattern(`pattern')"'
            exit 601
        }
    }
    else if `"`files'"' != "" {
        local rest `"`files'"'
        gettoken f rest : rest
        while `"`f'"' != "" {
            local ++nfiles
            local file`nfiles' `"`f'"'
            gettoken f rest : rest
        }
    }
    if `filesmode' {
        forvalues i = 1/`nfiles' {
            confirm file `"`file`i''"'
        }
        * wave names: wavenames() tokens, else the file basename minus .dta
        local nwn 0
        local restwn `"`wavenames'"'
        gettoken w restwn : restwn
        while `"`w'"' != "" {
            local ++nwn
            local wn`nwn' `"`macval(w)'"'
            gettoken w restwn : restwn
        }
        if `nwn' > 0 & `nwn' != `nfiles' {
            di as err "wavenames() lists `nwn' names for `nfiles' files"
            exit 198
        }
        if `nwn' == 0 {
            forvalues i = 1/`nfiles' {
                local bn `"`file`i''"'
                local sl = max(strrpos(`"`bn'"', "/"), strrpos(`"`bn'"', char(92)))
                if `sl' > 0 local bn = substr(`"`bn'"', `sl' + 1, .)
                local dt = strrpos(`"`bn'"', ".")
                if `dt' > 0 local bn = substr(`"`bn'"', 1, `dt' - 1)
                local wn`i' `"`bn'"'
            }
        }
        local nw = `nfiles'
    }

    * ---- in-memory mode: sample selection ---------------------------------------
    if !`filesmode' {
        if "`varlist'" == "" {
            if c(k) == 0 {
                di as err "no variables to document: the dataset in memory is empty and no files() or folder() was specified"
                exit 2000
            }
            unab varlist : _all
        }
        if _N == 0 {
            di as err "no observations: the dataset in memory has variables but 0 observations;"
            di as err "    datadictionary needs at least one observation to document"
            exit 2000
        }
        marksample touse, novarlist strok
        quietly count if `touse'
        if r(N) == 0 {
            di as err "no observations selected by the varlist/if/in restriction"
            exit 2000
        }
    }

    * ---- everything below runs on scratch copies; the caller's data are
    * ---- restored automatically when the program exits --------------------------
    capture preserve
    local srcname = cond(`"`c(filename)'"' == "", "data in memory", `"`c(filename)'"')

    tempname MH VH CH FF
    tempfile MAIN VLAB CHG SIG CHGF
    postfile `MH' int wavenum str80 wave str32 name str12 type str49 format ///
        str80 varlab str32 vallab double n double pctmiss double distinct   ///
        double mean double sd double min double p50 double max              ///
        str2000 examples str2000 notes str2000 srctag str2000 chars         ///
        using `"`MAIN'"'
    postfile `VH' int wavenum str32 lname double value str2000 label using `"`VLAB'"'

    local totnotes 0
    local lbls ""

    * ============================ FILES MODE ======================================
    if `filesmode' {
        forvalues i = 1/`nfiles' {
            quietly use `"`file`i''"', clear
            local N`i' = _N
            _dd_rows, mh(`MH') wavenum(`i') wave(`"`macval(wn`i')'"')  ///
                examples(`examples') top(`top') `nochars' `nonotes'
            local k`i' = r(k)
            local totnotes = `totnotes' + r(nnotes)
            local flbl `"`r(lblnames)'"'
            if `"`flbl'"' != "" {
                _dd_postvl, vh(`VH') waves(`i') labels(`flbl')
            }
        }
        local nw = `nfiles'
    }

    * =========================== IN-MEMORY MODE ===================================
    else {
        quietly keep if `touse'
        local keepvars `varlist'
        if "`wave'" != "" local keepvars : list keepvars | wave
        quietly keep `keepvars'
        local NKEPT = _N

        * ---- relabel do-file and/or dictionary, from the full documented data
        * ---- in memory (harvesting below may subset or overwrite it) -----------
        if `"`dofile'"' != "" {
            _dd_dofile, dofile(`"`dofile'"') srcname(`"`srcname'"') ///
                `nochars' `nonotes' `norecast'
        }
        if `"`dictionary'"' != "" {
            _dd_dict, dictionary(`"`dictionary'"') srcname(`"`srcname'"')
        }

        if "`wave'" == "" {
            * ---- cross-sectional: one codebook row per variable ----
            _dd_rows, mh(`MH') wavenum(0) wave("") vars(`varlist') ///
                examples(`examples') top(`top') `nochars' `nonotes'
            local totnotes = r(nnotes)
            local lbls `"`r(lblnames)'"'
            local nw 0
            if `"`lbls'"' != "" {
                _dd_postvl, vh(`VH') waves(0) labels(`lbls')
            }
        }
        else {
            * ---- stitched panel: one codebook row per variable per wave.
            * ---- Stitching leaves one value-label set per variable, so per-wave
            * ---- value labels and label-change detection are not available here
            * ---- (use files mode for those); per-wave statistics and missingness
            * ---- are.  A variable all-missing within a wave shows 100% missing. -
            * Waves are numbered by egen group() (numeric order, or sorted
            * strings; missing waves left out, as levelsof does) and each
            * wave's name is read straight from the data, so a $ or a
            * backtick in a string wave value is never macro-expanded.
            capture confirm string variable `wave'
            local strwave = (_rc == 0)
            local wvallab : value label `wave'
            tempvar wg wrow
            quietly egen long `wg' = group(`wave')
            quietly summarize `wg', meanonly
            local nw = cond(r(N) > 0, r(max), 0)
            quietly gen long `wrow' = _n
            forvalues w = 1/`nw' {
                quietly summarize `wrow' if `wg' == `w', meanonly
                local o = r(min)
                if `strwave' {
                    local wn`w' = `wave'[`o']
                }
                else if "`wvallab'" != "" {
                    local wv = `wave'[`o']
                    local wn`w' : label (`wave') `wv'
                }
                else local wn`w' = strtrim(string(`wave'[`o'], "%18.0g"))
            }
            quietly drop `wrow'
            local gvars : list keepvars - wave
            tempfile MEMALL
            quietly save `"`MEMALL'"'
            forvalues w = 1/`nw' {
                quietly use `"`MEMALL'"', clear
                quietly keep if `wg' == `w'
                local N`w' = _N
                quietly keep `gvars'
                _dd_rows, mh(`MH') wavenum(`w') wave(`"`macval(wn`w')'"') vars(`gvars') ///
                    examples(`examples') top(`top') `nochars' `nonotes'
                local k`w' = r(k)
                local totnotes = `totnotes' + r(nnotes)
                local lbls `"`lbls' `r(lblnames)'"'
            }
            local lbls : list uniq lbls
            * surviving value labels (one set per variable in a stitched file);
            * repeated per wave so the ValueLabels sheet lines up with Variables
            quietly use `"`MEMALL'"', clear
            if `"`lbls'"' != "" & `nw' > 0 {
                _dd_postvl, vh(`VH') waves(1/`nw') labels(`lbls')
            }
        }
    }

    postclose `MH'
    postclose `VH'

    quietly use `"`MAIN'"', clear
    local nvars = _N

    * ---- change detection across waves (files mode only: stitching waves into
    * ---- one file destroys per-wave value labels, so this cannot be done on a
    * ---- combined in-memory file) ------------------------------------------------
    local nchanges 0
    if `filesmode' {
        * one signature string per (wave, value-label set): "v=label | v=label"
        local havesig 0
        quietly use `"`VLAB'"', clear
        if _N > 0 {
            sort wavenum lname value
            quietly gen strL _p = string(value, "%13.0g") + "=" + label
            quietly by wavenum lname: gen strL _s = _p if _n == 1
            quietly by wavenum lname: replace _s = _s[_n - 1] + " | " + _p if _n > 1
            quietly by wavenum lname: keep if _n == _N
            quietly gen str2000 vsig = substr(_s, 1, 2000)
            keep wavenum lname vsig
            rename lname vallab
            quietly save `"`SIG'"'
            local havesig 1
        }
        quietly use `"`MAIN'"', clear
        if `havesig' {
            quietly merge m:1 wavenum vallab using `"`SIG'"', keep(1 3) ///
                keepusing(vsig) nogenerate
            quietly replace vsig = "" if vallab == ""
        }
        else quietly gen str1 vsig = ""
        tempfile MAINS
        quietly save `"`MAINS'"'

        postfile `CH' str80 wavepair str32 name str40 change ///
            str2000 before str2000 after using `"`CHG'"'
        postfile `FF' int wavenum str32 name str24 kind using `"`CHGF'"'
        forvalues i = 1/`= `nfiles' - 1' {
            local j = `i' + 1
            local wp `"`macval(wn`i')' -> `macval(wn`j')'"'
            quietly use `"`MAINS'"', clear
            quietly keep if wavenum == `i'
            keep name type format varlab vallab vsig
            foreach x in type format varlab vallab vsig {
                rename `x' `x'0
            }
            tempfile A
            quietly save `"`A'"'
            quietly use `"`MAINS'"', clear
            quietly keep if wavenum == `j'
            keep name type format varlab vallab vsig
            quietly merge 1:1 name using `"`A'"'
            sort name
            forvalues r = 1/`=_N' {
                local nm = name[`r']
                if _merge[`r'] == 2 {
                    post `CH' (`"`macval(wp)'"') ("`nm'") ("variable dropped") ("") ("")
                }
                else if _merge[`r'] == 1 {
                    post `CH' (`"`macval(wp)'"') ("`nm'") ("variable added") ("") ("")
                }
                else {
                    foreach x in type format varlab {
                        local b = `x'0[`r']
                        local a = `x'[`r']
                        if `"`macval(b)'"' != `"`macval(a)'"' {
                            if "`x'" == "type"   local ct "storage type changed"
                            if "`x'" == "format" local ct "display format changed"
                            if "`x'" == "varlab" local ct "variable label changed"
                            post `CH' (`"`macval(wp)'"') ("`nm'") ("`ct'") (`"`macval(b)'"') (`"`macval(a)'"')
                            if "`x'" == "varlab" post `FF' (`j') ("`nm'") ("label")
                        }
                    }
                    local lb = vallab0[`r']
                    local la = vallab[`r']
                    local sb = vsig0[`r']
                    local sa = vsig[`r']
                    if `"`lb'"' != `"`la'"' | `"`macval(sb)'"' != `"`macval(sa)'"' {
                        local btxt = cond(`"`lb'"' == "", "(none)", `"`lb': `macval(sb)'"')
                        local atxt = cond(`"`la'"' == "", "(none)", `"`la': `macval(sa)'"')
                        local btxt = substr(`"`macval(btxt)'"', 1, 2000)
                        local atxt = substr(`"`macval(atxt)'"', 1, 2000)
                        post `CH' (`"`macval(wp)'"') ("`nm'") ("value label set changed") ///
                            (`"`macval(btxt)'"') (`"`macval(atxt)'"')
                        post `FF' (`j') ("`nm'") ("categories")
                    }
                }
            }
        }
        postclose `CH'
        postclose `FF'
        quietly use `"`CHG'"', clear
        local nchanges = _N
    }

    * ---- attach a "changed since previous wave" flag to each codebook row.
    * ---- Only files mode can detect it: a stitched panel keeps one label set
    * ---- per variable, so a wave-to-wave label change leaves no trace.  The
    * ---- flag marks a variable whose meaning may have shifted between waves. --
    local haveflags 0
    if `filesmode' {
        quietly use `"`CHGF'"', clear
        if _N > 0 {
            quietly gen byte _lab = (kind == "label")
            quietly gen byte _cat = (kind == "categories")
            collapse (max) _lab _cat, by(wavenum name)
            quietly gen str24 changed = cond(_lab & _cat, "label+categories", ///
                cond(_lab == 1, "label", "categories"))
            keep wavenum name changed
            tempfile FLAGS
            quietly save `"`FLAGS'"'
            local haveflags 1
        }
    }
    quietly use `"`MAIN'"', clear
    quietly gen long _seq = _n
    if `haveflags' {
        quietly merge 1:1 wavenum name using `"`FLAGS'"', keep(1 3) nogenerate
    }
    sort _seq
    quietly drop _seq
    capture confirm variable changed
    if _rc quietly gen str24 changed = ""
    quietly replace changed = "" if changed == "."
    quietly save `"`MAIN'"', replace

    * ---- flow(): append surveymap's pct_answered_sm and skipped_by_sm to the
    * ---- codebook rows, matched on variable name.  Applied to `MAIN' here so
    * ---- both the Variables sheet and the saving() dataset carry the columns.
    if `"`flow'"' != "" {
        _dd_flow, flow(`"`flow'"') main(`"`MAIN'"')
    }

    * ---- display ---------------------------------------------------------------------
    local overtime = (`nw' > 0)
    di as txt _n "datadictionary 1.0.2"
    if `filesmode' {
        di as txt "  mode: " as res "files" as txt "    files: " as res `nfiles' ///
            as txt "    codebook rows: " as res `nvars'
        di as txt "  changes detected across waves: " as res `nchanges'
    }
    else {
        di as txt "  mode: " as res "in-memory" as txt "    source: " as res `"`srcname'"'
        di as txt "  observations: " as res `NKEPT' as txt "    variables documented: " as res `nvars'
        if `overtime' di as txt "  stitched waves (" as res "`wave'" as txt "): " as res `nw'
    }

    quietly use `"`MAIN'"', clear
    local lastw = -1
    forvalues r = 1/`=_N' {
        if wavenum[`r'] != `lastw' {
            local lastw = wavenum[`r']
            if `overtime' {
                di as txt _n "{hline 80}"
                di as txt "wave " as res `"`macval(wn`lastw')'"' as txt ///
                    "  (N = " as res `N`lastw'' as txt ", variables = " as res `k`lastw'' as txt ")"
            }
            di as txt "{hline 80}"
            di as txt %-13s "name" %-8s "type" %-9s "format" ///
                %8s "N" %7s "miss%" %6s "dist" "  " %-24s "label" ///
                cond(`overtime', "  changed", "")
            di as txt "{hline 80}"
        }
        local nm = name[`r']
        local ty = type[`r']
        local fm = format[`r']
        local vl = varlab[`r']
        local cf = changed[`r']
        di as res %-13s abbrev("`nm'", 12) as txt %-8s "`ty'" ///
            %-9s abbrev("`fm'", 8) as res %8.0f n[`r'] %7.1f pctmiss[`r'] ///
            %6.0f distinct[`r'] as txt "  " %-24s abbrev(`"`macval(vl)'"', 24) _c
        if `overtime' & "`cf'" != "" di as err "  <- `cf'"
        else di ""
    }
    di as txt "{hline 80}"

    if `filesmode' & `nchanges' > 0 {
        di as txt _n "Changes detected across waves:"
        quietly use `"`CHG'"', clear
        forvalues r = 1/`=_N' {
            local wp = wavepair[`r']
            local nm = name[`r']
            local ct = change[`r']
            local b  = before[`r']
            local a  = after[`r']
            di as txt "  " %-16s `"`macval(wp)'"' as res %-13s abbrev("`nm'", 12) ///
                as txt %-26s "`ct'" _c
            if `"`macval(b)'`macval(a)'"' != "" {
                di as txt "  " abbrev(`"`macval(b)'"', 24) " -> " abbrev(`"`macval(a)'"', 24)
            }
            else di ""
        }
    }

    * ---- saving(): the machine-readable codebook -----------------------------------
    if `"`saving'"' != "" {
        quietly use `"`MAIN'"', clear
        if !`overtime' quietly drop wave wavenum changed
        else order wave name, first
        label variable name     "variable name"
        label variable type     "storage type"
        label variable format   "display format"
        label variable varlab   "variable label"
        label variable vallab   "value-label name"
        label variable n        "N nonmissing"
        label variable pctmiss  "% missing"
        label variable distinct "distinct nonmissing values"
        label variable mean     "mean"
        label variable sd       "std. dev."
        label variable min      "minimum"
        label variable p50      "median"
        label variable max      "maximum"
        label variable examples "example values / top categories"
        label variable notes    "stored notes"
        label variable srctag   "char [source] (srctag/combineall/projectbuilder)"
        label variable chars    "other characteristics"
        if `overtime' {
            label variable wave    "wave"
            label variable wavenum "wave order"
            capture label variable changed "changed vs previous wave"
        }
        label data "datadictionary codebook: `srcname'"
        quietly compress
        quietly save `"`saving'"', replace
        di as txt _n "wrote " as res `"`saving'"'
    }

    * ---- excel(): multi-sheet workbook ------------------------------------------------
    if `"`excel'"' != "" {
        * Overview sheet (created first so it is the workbook's first sheet)
        putexcel set `"`excel'"', sheet("Overview") replace open
        putexcel A1 = "datadictionary codebook", bold
        putexcel A2 = "Generated"
        putexcel B2 = "`c(current_date)' `c(current_time)'"
        putexcel A3 = "Mode"
        local modestr = cond(`filesmode', "files", "in-memory")
        putexcel B3 = "`modestr'"
        putexcel A4 = "Source"
        if `filesmode' {
            local srclist ""
            forvalues i = 1/`nfiles' {
                local srclist `"`srclist'`file`i''; "'
            }
            local srclist = substr(`"`srclist'"', 1, max(1, strlen(`"`srclist'"') - 2))
            putexcel B4 = `"`srclist'"'
        }
        else putexcel B4 = `"`srcname'"'
        putexcel A5 = "Codebook rows"
        putexcel B5 = `nvars'
        putexcel A6 = "Variable notes harvested"
        putexcel B6 = `totnotes'
        local rr 7
        if `filesmode' {
            putexcel A`rr' = "Changes detected"
            putexcel B`rr' = `nchanges'
            local ++rr
        }
        local ++rr
        if `overtime' {
            putexcel A`rr' = "Wave", bold
            putexcel B`rr' = "N", bold
            putexcel C`rr' = "Variables", bold
            forvalues w = 1/`nw' {
                local ++rr
                putexcel A`rr' = `"`macval(wn`w')'"'
                putexcel B`rr' = `N`w''
                putexcel C`rr' = `k`w''
            }
        }
        else {
            putexcel A`rr' = "N", bold
            putexcel B`rr' = "Variables", bold
            local ++rr
            putexcel A`rr' = `NKEPT'
            putexcel B`rr' = `nvars'
        }
        putexcel save

        * Variables sheet: the codebook.  % missing sits beside the statistics,
        * common values, labels, and notes; over-time modes add a wave column
        * and a "changed vs previous wave" flag.  (No separate Missingness sheet:
        * pctmiss is a column here.)
        quietly use `"`MAIN'"', clear
        quietly drop wavenum
        if !`overtime' quietly drop wave changed
        else order wave name, first
        if _N > 0 {
            quietly export excel using `"`excel'"', sheet("Variables") ///
                sheetreplace firstrow(variables)
        }
        _dd_bold, file(`"`excel'"') sheet("Variables")

        * ValueLabels sheet
        quietly use `"`VLAB'"', clear
        if `overtime' {
            quietly gen str80 wave = ""
            forvalues w = 1/`nw' {
                quietly replace wave = `"`macval(wn`w')'"' if wavenum == `w'
            }
            order wave lname value label
        }
        quietly drop wavenum
        if _N > 0 {
            quietly export excel using `"`excel'"', sheet("ValueLabels") ///
                sheetreplace firstrow(variables)
        }
        _dd_bold, file(`"`excel'"') sheet("ValueLabels")

        * Changes sheet (files mode only: see the change-detection note above)
        if `filesmode' {
            quietly use `"`CHG'"', clear
            if _N > 0 {
                quietly export excel using `"`excel'"', sheet("Changes") ///
                    sheetreplace firstrow(variables)
            }
            _dd_bold, file(`"`excel'"') sheet("Changes")
        }

        di as txt "wrote " as res `"`excel'"'
    }

    if `"`dofile'"' != ""     di as txt "wrote " as res `"`dofile'"' as txt " (relabel do-file)"
    if `"`dictionary'"' != "" di as txt "wrote " as res `"`dictionary'"' as txt " (infile dictionary)"

    * ---- clickable links to open the outputs and their folder --------------------------
    if `"`excel'`saving'`dofile'`dictionary'"' != "" {
        di as txt _n "Open:"
        global DD_NLINK ""
        if `"`excel'"'      != "" _dd_link, path(`"`excel'"')      tag("codebook (Excel)")
        if `"`saving'"'     != "" _dd_link, path(`"`saving'"')     tag("codebook (.dta)")
        if `"`dofile'"'     != "" _dd_link, path(`"`dofile'"')     tag("relabel do-file")
        if `"`dictionary'"' != "" _dd_link, path(`"`dictionary'"') tag("infile dictionary")
        _dd_link, path(`"`excel'`saving'`dofile'`dictionary'"') tag("containing folder") folder
    }

    * ---- stored results -----------------------------------------------------------------
    return scalar nvars    = `nvars'
    return scalar nchanges = `nchanges'
    if `"`excel'"' != ""      return local xlsx `"`excel'"'
    if `"`saving'"' != ""     return local dta `"`saving'"'
    if `"`dofile'"' != ""     return local dofile `"`dofile'"'
    if `"`dictionary'"' != "" return local dct `"`dictionary'"'
end


* ---------------------------------------------------------------------------
* _dd_link: print a clickable SMCL link that opens a file (or its folder) in
* the OS.  The path is made absolute against the current directory so the link
* works no matter where the Results window scrolls to.
* ---------------------------------------------------------------------------
program define _dd_link
    version 16.0
    syntax , PATH(string) TAG(string) [ FOLDER ]
    * absolute path.  A leading ~ is expanded the way Stata's own file
    * commands expand it (HOME; on Windows USERPROFILE, then HOMEDRIVE +
    * HOMEPATH, then HOME), and a path starting with / or \ (including a
    * \\server share) or a drive letter is already absolute.
    local p `"`path'"'
    if substr(`"`p'"', 1, 1) == "~" & inlist(substr(`"`p'"', 2, 1), "", "/", char(92)) {
        local hm : environment HOME
        if "`c(os)'" == "Windows" {
            local up : environment USERPROFILE
            local hd : environment HOMEDRIVE
            local hp : environment HOMEPATH
            if `"`up'"' != "" local hm `"`up'"'
            else if `"`hd'`hp'"' != "" local hm `"`hd'`hp'"'
        }
        local rest = substr(`"`p'"', 2, .)
        if `"`hm'"' != "" local p `"`hm'`rest'"'
    }
    if !inlist(substr(`"`p'"', 1, 1), "/", char(92)) & substr(`"`p'"', 2, 1) != ":" {
        local p `"`c(pwd)'/`p'"'
    }
    if "`folder'" != "" {
        * strip to the directory
        local sl = max(strrpos(`"`p'"', "/"), strrpos(`"`p'"', char(92)))
        if `sl' > 1 local p = substr(`"`p'"', 1, `sl' - 1)
    }
    * The link runs a command rather than handing a path to {browse}: SMCL
    * gives a {browse} target to the platform URL parser, and on macOS that
    * can abort Stata outright.  The OS opener also picks the right
    * application for a .xlsx or a folder, which a browser does not.
    * The path travels in a global so the directive itself carries no quote,
    * space, or colon (a Windows path starts "C:", and a colon inside
    * {stata ...} would split the command from its label).
    global DD_NLINK = cond("$DD_NLINK" == "", 1, $DD_NLINK + 1)
    global DD_OPEN${DD_NLINK} `"`p'"'
    di as txt `"  {stata _dd_open ${DD_NLINK}:`tag'}"'
end


* ---------------------------------------------------------------------------
* _dd_flow: merge the item rows of a surveymap journal into the codebook
* tempfile, adding pct_answered_sm (percent of respondents in scope who
* answered the item) and skipped_by_sm (the skip logic that routes
* respondents around it, e.g. "voted==0").  The journal is a tab-separated
* file read by column name; it must carry class, var, pct_answered, and
* gated_by columns or the command stops with error 459.  Codebook rows keep
* their order and their key column "name"; unmatched codebook rows get
* missing/empty values; journal items absent from the codebook are dropped
* and counted in one note line.  The _sm suffix keeps the new columns clear
* of the codebook's own.  Runs on scratch data; callers reload `MAIN' after.
* ---------------------------------------------------------------------------
program define _dd_flow
    version 16.0
    syntax , FLOW(string) MAIN(string)

    quietly import delimited `"`flow'"', delimiter(tab) varnames(1) ///
        stringcols(_all) clear
    foreach c in class var pct_answered gated_by {
        capture confirm variable `c'
        if _rc {
            di as err `"flow(): `flow' is not a surveymap journal (no `c' column)"'
            exit 459
        }
    }
    quietly keep if class == "item"
    quietly gen name = var
    quietly gen double pct_answered_sm = real(pct_answered)
    quietly gen skipped_by_sm = gated_by
    quietly replace skipped_by_sm = "" if skipped_by_sm == "."
    quietly keep name pct_answered_sm skipped_by_sm
    quietly duplicates drop name, force
    tempfile FJ
    quietly save `"`FJ'"'

    quietly use `"`main'"', clear
    quietly gen long _seq = _n
    quietly merge m:1 name using `"`FJ'"'
    quietly count if _merge == 2
    local nun = r(N)
    quietly drop if _merge == 2
    quietly drop _merge
    sort _seq
    quietly drop _seq
    label variable pct_answered_sm "% answered (surveymap journal)"
    label variable skipped_by_sm   "routed around by (surveymap journal)"
    order pct_answered_sm skipped_by_sm, last
    quietly save `"`main'"', replace
    if `nun' > 0 {
        di as txt "flow(): " as res `nun' as txt ///
            " journal item(s) have no codebook row and were skipped"
    }
end


* ---------------------------------------------------------------------------
* _dd_rows: harvest one codebook row per variable of the dataset in memory
* and post it to the main postfile.  Returns r(k) (variables documented),
* r(nnotes) (variable notes seen), and r(lblnames) (value labels attached).
* The routine sorts the data while computing distinct counts and example
* values; callers must not rely on row order afterward.
* ---------------------------------------------------------------------------
program define _dd_rows, rclass
    version 16.0
    syntax , MH(name) WAVENUM(integer) EXAMPLES(integer) TOP(integer) ///
        [ WAVE(string) VARS(string) NOCHARS NONOTES ]

    if `"`vars'"' == "" unab vars : _all
    local NT = _N
    local wavelab = substr(`"`macval(wave)'"', 1, 80)
    local nnotes 0
    local lblnames ""
    local k 0

    foreach v of local vars {
        local ++k
        local ty : type `v'
        local fm : format `v'
        local vl : variable label `v'
        local ll : value label `v'
        if "`ll'" != "" local lblnames `lblnames' `ll'
        local isstr = (strpos("`ty'", "str") == 1)

        * N nonmissing and % missing
        if `isstr' quietly count if `v' != ""
        else quietly count if !missing(`v')
        local nn = r(N)
        local pctm = cond(`NT' > 0, 100 * (`NT' - `nn') / `NT', .)

        * distinct nonmissing values
        local dist 0
        if `nn' > 0 {
            tempvar tg
            if `isstr' {
                quietly bysort `v': gen byte `tg' = (_n == 1 & `v' != "")
            }
            else quietly bysort `v': gen byte `tg' = (_n == 1 & !missing(`v'))
            quietly count if `tg'
            local dist = r(N)
            drop `tg'
        }

        * numeric summary statistics (blank for strings)
        local mn .
        local sd .
        local mi .
        local md .
        local mx .
        if !`isstr' & `nn' > 0 {
            quietly summarize `v', detail
            local mn = r(mean)
            local sd = r(sd)
            local mi = r(min)
            local md = r(p50)
            local mx = r(max)
        }

        * example values: distinct examples for strings; top categories by
        * frequency, as "label (n, pct%)", for value-labeled variables
        local ex ""
        if `isstr' & `nn' > 0 {
            sort `v'
            local ct 0
            local o 1
            * the data are sorted, so a new distinct value differs from the
            * row above; comparing in the data (not in macros) keeps $ and
            * backticks in a value from being expanded
            while `ct' < `examples' & `o' <= `NT' {
                if `v'[`o'] != "" & (`o' == 1 | `v'[`o'] != `v'[`o' - 1]) {
                    local cur = `v'[`o']
                    local ++ct
                    if `ct' == 1 {
                        local ex `"`macval(cur)'"'
                    }
                    else local ex `"`macval(ex)', `macval(cur)'"'
                }
                local ++o
            }
        }
        else if "`ll'" != "" & `nn' > 0 {
            tempname F R
            capture quietly tabulate `v', sort matcell(`F') matrow(`R')
            if _rc == 0 {
                local tot = r(N)
                local take = min(`top', rowsof(`R'))
                forvalues j = 1/`take' {
                    local vv = `R'[`j', 1]
                    local ff = `F'[`j', 1]
                    local pc = strtrim(string(100 * `ff' / `tot', "%5.1f"))
                    capture local lb : label (`v') `vv'
                    if _rc local lb "`vv'"
                    if `j' == 1 {
                        local ex `"`macval(lb)' (`ff', `pc'%)"'
                    }
                    else local ex `"`macval(ex)', `macval(lb)' (`ff', `pc'%)"'
                }
            }
        }
        local ex = substr(`"`macval(ex)'"', 1, 2000)

        * stored notes
        local ntxt ""
        if "`nonotes'" == "" {
            local k0 : char `v'[note0]
            capture local k0 = int(real("`k0'"))
            if "`k0'" == "" | "`k0'" == "." local k0 0
            forvalues j = 1/`k0' {
                local t : char `v'[note`j']
                if `j' == 1 {
                    local ntxt `"`j'. `macval(t)'"'
                }
                else local ntxt `"`macval(ntxt)' | `j'. `macval(t)'"'
            }
            local nnotes = `nnotes' + `k0'
            local ntxt = substr(`"`macval(ntxt)'"', 1, 2000)
        }

        * characteristics: the provenance stamp in the srctag column, all
        * others concatenated.  The stamp is char[source], which srctag,
        * combineall and projectbuilder write (1.0.2; 1.0.1 and earlier read
        * char[srctag], which none of them writes, so the column was empty).
        * A variable with no char[source] but a char[srctag] still has that
        * one shown in the column.
        local st ""
        local ch ""
        if "`nochars'" == "" {
            local stc "source"
            local st : char `v'[source]
            if `"`macval(st)'"' == "" {
                local stc "srctag"
                local st : char `v'[srctag]
            }
            local st = substr(`"`macval(st)'"', 1, 2000)
            local allc : char `v'[]
            foreach c of local allc {
                if "`c'" == "`stc'" continue
                if regexm("`c'", "^note[0-9]+$") | "`c'" == "note0" continue
                local cv : char `v'[`c']
                if `"`macval(ch)'"' == "" {
                    local ch `"`c'=`macval(cv)'"'
                }
                else local ch `"`macval(ch)'; `c'=`macval(cv)'"'
            }
            local ch = substr(`"`macval(ch)'"', 1, 2000)
        }

        post `mh' (`wavenum') (`"`macval(wavelab)'"') ("`v'") ("`ty'") ("`fm'") ///
            (`"`macval(vl)'"') ("`ll'") (`nn') (`pctm') (`dist')          ///
            (`mn') (`sd') (`mi') (`md') (`mx')                            ///
            (`"`macval(ex)'"') (`"`macval(ntxt)'"') (`"`macval(st)'"')    ///
            (`"`macval(ch)'"')
    }

    local lblnames : list uniq lblnames
    return local lblnames `lblnames'
    return scalar nnotes = `nnotes'
    return scalar k = `k'
end


* ---------------------------------------------------------------------------
* _dd_postvl: post every value of the named value labels to the value-label
* postfile, once per wave in waves().  Reads the labels with st_vlload rather
* than -uselabel-, which runs -label save- output back through the macro
* expander and so turns a $name in label text into the global's contents.
* ---------------------------------------------------------------------------
program define _dd_postvl
    version 16.0
    syntax , VH(name) WAVES(numlist integer >=0) LABELS(namelist)
    * alphabetical by label name, the order -uselabel- produced
    local labels : list sort labels
    foreach lname of local labels {
        mata: _dd_vlload("`lname'", 0)
        forvalues j = 1/`__dd_nv' {
            foreach w of local waves {
                post `vh' (`w') ("`lname'") (`__dd_v`j'') (`"`macval(__dd_t`j')'"')
            }
        }
    }
end


* ---------------------------------------------------------------------------
* _dd_bold: bold the header row of one sheet via putexcel.  Headers come from
* the dataset in memory (variable names, or variable labels with -labels-).
* putexcel creates the sheet when it does not exist yet, so this also writes
* header-only sheets for empty tables.
* ---------------------------------------------------------------------------
program define _dd_bold
    version 16.0
    syntax , FILE(string) SHEET(string) [ LABels ]
    unab allv : _all
    local k : word count `allv'
    putexcel set `"`file'"', sheet("`sheet'") modify open
    forvalues c = 1/`k' {
        local v : word `c' of `allv'
        if "`labels'" != "" {
            local h : variable label `v'
            if `"`h'"' == "" local h "`v'"
        }
        else local h "`v'"
        if `c' <= 26 local L = char(64 + `c')
        else local L = char(64 + int((`c' - 1) / 26)) + char(65 + mod(`c' - 1, 26))
        putexcel `L'1 = `"`macval(h)'"', bold
    }
    putexcel save
end


* ---------------------------------------------------------------------------
* _dd_dofile: write a do-file that re-applies variable labels, value labels,
* display formats, storage types, notes, and characteristics to a dataset
* after a CSV/Excel round-trip.  Runs on the documented data in memory.  Every
* restore is -capture-d so a renamed/dropped column is skipped, not fatal, and
* a receipt at the foot reports what did not match on re-ingestion.
* ---------------------------------------------------------------------------
program define _dd_dofile
    version 16.0
    syntax , DOfile(string) SRCname(string) [ NOCHars NONotes NORECast ]

    unab vars : _all

    * attached value labels, in variable order, unique
    local lblnames ""
    foreach v of local vars {
        local ll : value label `v'
        if "`ll'" != "" local lblnames `lblnames' `ll'
    }
    local lblnames : list uniq lblnames

    * basename for the -do- hint in the header
    local base `"`dofile'"'
    local sl = max(strrpos(`"`base'"', "/"), strrpos(`"`base'"', char(92)))
    if `sl' > 0 local base = substr(`"`base'"', `sl' + 1, .)

    tempname fh
    file open `fh' using `"`dofile'"', write text replace
    file write `fh' `"*! Relabel do-file written by datadictionary 1.0.2"' _n
    file write `fh' `"*! Source: `srcname'"' _n
    file write `fh' `"*! Generated: `c(current_date)' `c(current_time)'"' _n
    file write `fh' `"*!"' _n
    file write `fh' `"*! Restores variable labels, value labels, display formats, storage types,"' _n
    file write `fh' `"*! notes, and characteristics after a CSV/Excel round-trip (e.g. a file sent"' _n
    file write `fh' `"*! to a collaborator working in R, Python, or Excel and returned as data)."' _n
    file write `fh' `"*! Typical round-trip:"' _n
    file write `fh' `"*!     export delimited using "share.csv", nolabel quote replace"' _n
    file write `fh' `"*!     * ...collaborator edits share.csv in R/Python/Excel and returns it..."' _n
    file write `fh' `"*!     import delimited using "share.csv", varnames(1) case(preserve) bindquote(strict) clear"' _n
    file write `fh' `"*!     do `base'"' _n
    file write `fh' `"*! Export with -nolabel- so value-labeled variables travel as their numeric"' _n
    file write `fh' `"*! codes; this file reattaches the code-to-label mappings.  Every command below"' _n
    file write `fh' `"*! is -capture-d, so a column the collaborator renamed or dropped is skipped"' _n
    file write `fh' `"*! rather than stopping the run; the receipt at the foot reports what did not"' _n
    file write `fh' `"*! match.  -quote- on export and -bindquote(strict)- on import keep a text"' _n
    file write `fh' `"*! value that holds a line break (a free-text answer) in one row."' _n
    file write `fh' "" _n

    * match column names exactly (not by abbreviation), so a renamed column is
    * skipped, never fuzzily relabeled; the prior setting is restored at the end
    file write `fh' `"local __dd_va = c(varabbrev)"' _n
    file write `fh' `"set varabbrev off"' _n
    file write `fh' "" _n

    * value-label definitions, one -label define ..., modify- line per value
    * (the form -label save- writes), with $ and backticks in the label text
    * escaped so that running the do-file does not macro-expand them
    if "`lblnames'" != "" {
        file write `fh' `"* ---- value-label definitions ----"' _n
        foreach lname of local lblnames {
            mata: _dd_vlload("`lname'", 1)
            forvalues j = 1/`__dd_nv' {
                local L `"label define `lname' `__dd_v`j'' `"`macval(__dd_t`j')'"', modify"'
                file write `fh' `"`macval(L)'"' _n
            }
        }
        file write `fh' "" _n
    }

    * per-variable: storage type, variable label, format, value label
    file write `fh' `"* ---- variable labels, storage types, formats, value labels ----"' _n
    foreach v of local vars {
        local ty : type `v'
        local fm : format `v'
        local vl : variable label `v'
        local ll : value label `v'
        if "`norecast'" == "" file write `fh' `"capture recast `ty' `v'"' _n
        if `"`macval(vl)'"' != "" {
            mata: st_local("vl", _dd_esc(st_local("vl")))
            local L `"capture label variable `v' `"`macval(vl)'"'"'
            file write `fh' `"`macval(L)'"' _n
        }
        file write `fh' `"capture format `v' `fm'"' _n
        if "`ll'" != "" file write `fh' `"capture label values `v' `ll'"' _n
    }
    file write `fh' "" _n

    * notes
    if "`nonotes'" == "" {
        local wrotehdr 0
        foreach v of local vars {
            local k0 : char `v'[note0]
            capture local k0 = int(real("`k0'"))
            if "`k0'" == "" | "`k0'" == "." local k0 0
            forvalues j = 1/`k0' {
                if !`wrotehdr' {
                    file write `fh' `"* ---- notes ----"' _n
                    local wrotehdr 1
                }
                local t : char `v'[note`j']
                mata: st_local("t", _dd_esc(st_local("t")))
                * -note- expands its text a second time, so no escaping
                * survives it; the note is appended through the note0 and
                * noteN characteristics instead.  nref holds a literal
                * reference to the local __dd_n, built from char() so that
                * it is written to the do-file unexpanded
                local nref = char(96) + "__dd_n" + char(39)
                local L1 `"capture confirm variable `v', exact"'
                local L2 `"if !_rc {"'
                local L3 `"    local __dd_n : char `v'[note0]"'
                local L4 `"    local __dd_n = cond(real("`macval(nref)'") < ., real("`macval(nref)'"), 0) + 1"'
                local L5 `"    char define `v'[note`macval(nref)'] `"`macval(t)'"'"'
                local L6 `"    char define `v'[note0] `macval(nref)'"'
                local L7 `"}"'
                forvalues q = 1/7 {
                    file write `fh' `"`macval(L`q')'"' _n
                }
            }
        }
        if `wrotehdr' file write `fh' "" _n
    }

    * characteristics (the char[source] stamp and any others; notes above)
    if "`nochars'" == "" {
        local wrotehdr 0
        foreach v of local vars {
            local allc : char `v'[]
            foreach c of local allc {
                if regexm("`c'", "^note[0-9]+$") | "`c'" == "note0" continue
                local cv : char `v'[`c']
                mata: st_local("cv", _dd_esc(st_local("cv")))
                if !`wrotehdr' {
                    file write `fh' `"* ---- characteristics (including the char[source] stamp) ----"' _n
                    local wrotehdr 1
                }
                local L `"capture char define `v'[`c'] `"`macval(cv)'"'"'
                file write `fh' `"`macval(L)'"' _n
            }
        }
        if `wrotehdr' file write `fh' "" _n
    }

    * re-ingestion receipt: what matched, what did not.  The receipt is plain
    * Stata that runs when the collaborator's file is re-imported.  It contains
    * `macro' references, which cannot be emitted through ordinary macro
    * expansion (the produced backtick would re-expand); each line is stored as
    * a template with @ standing for the open-quote ` and | for the close-quote
    * ', then subinstr swaps in the real characters and -macval- writes the
    * result verbatim.
    local T1  `"* ---- re-ingestion receipt: what matched, what did not ----"'
    local T2  `"local __dd_expected "`vars'""'
    local T3  `"local __dd_missing """'
    local T4  `"foreach __dd_v of local __dd_expected {"'
    local T5  `"    capture confirm variable @__dd_v|, exact"'
    local T6  `"    if _rc local __dd_missing "@__dd_missing| @__dd_v|""'
    local T7  `"}"'
    local T8  `"capture unab __dd_present : _all"'
    local T9  `"local __dd_extra : list __dd_present - __dd_expected"'
    local T10 `"local __dd_ne : word count @__dd_expected|"'
    local T11 `"local __dd_nm : word count @__dd_missing|"'
    local T12 `"local __dd_nr = @__dd_ne| - @__dd_nm|"'
    local T13 `"display as text _n "{hline 64}""'
    local T14 `"display as text "datadictionary relabel receipt""'
    local T15 `"display as text "  expected variables : @__dd_ne|""'
    local T16 `"display as text "  restored (matched) : @__dd_nr|""'
    local T17 `"if "@__dd_missing|" != "" display as text "  NOT found (renamed or dropped?):@__dd_missing|""'
    local T18 `"if "@__dd_extra|" != "" display as text "  extra columns (added, not in codebook):@__dd_extra|""'
    local T19 `"display as text "{hline 64}""'
    local T20 `"set varabbrev @__dd_va|"'
    forvalues i = 1/20 {
        local L = subinstr(subinstr(`"`T`i''"', "@", char(96), .), "|", char(39), .)
        file write `fh' `"`macval(L)'"' _n
    }
    file close `fh'
end


* ---------------------------------------------------------------------------
* _dd_dict: write a free-format -infile- dictionary (.dct) describing storage
* type and variable label per variable, for teams that want a Stata dictionary
* for archival or single-step typed ingestion.  A dictionary is legacy and
* narrower than the relabel do-file: free-format -infile- is WHITESPACE- (not
* comma-) delimited and a dictionary carries type + variable label only (no
* value labels, notes, or chars).  It reads a tab/space-delimited file whose
* strings are quoted and whose value-labeled variables are exported as numeric
* codes, with the header row skipped by _first(2).  For the general CSV
* round-trip use -import delimited- plus the relabel do-file instead.
* ---------------------------------------------------------------------------
program define _dd_dict
    version 16.0
    syntax , DICTionary(string) SRCname(string)

    unab vars : _all

    * default data-file reference: same basename as the dictionary, .txt
    local dbase `"`dictionary'"'
    local sl = max(strrpos(`"`dbase'"', "/"), strrpos(`"`dbase'"', char(92)))
    if `sl' > 0 local dbase = substr(`"`dbase'"', `sl' + 1, .)
    local dt = strrpos(`"`dbase'"', ".")
    if `dt' > 0 local dbase = substr(`"`dbase'"', 1, `dt' - 1)
    local dataref `"`dbase'.txt"'

    tempname fh
    file open `fh' using `"`dictionary'"', write text replace
    file write `fh' `"infile dictionary using "`dataref'" {"' _n
    file write `fh' `"    _first(2)"' _n
    file write `fh' `"    * datadictionary dictionary for `srcname'"' _n
    file write `fh' `"    * generated `c(current_date)' `c(current_time)'"' _n
    file write `fh' `"    * Storage type + variable label only.  Value labels, notes, and"' _n
    file write `fh' `"    * characteristics need the companion relabel do-file (datadictionary,"' _n
    file write `fh' `"    * dofile()).  Free-format -infile- is WHITESPACE-delimited, so prepare the"' _n
    file write `fh' `"    * data file with:"' _n
    file write `fh' `"    *     export delimited using "`dataref'", delimiter(tab) nolabel quote replace"' _n
    file write `fh' `"    * (numeric codes for labeled variables, strings quoted, tab separators)."' _n
    file write `fh' `"    * The header row is skipped by _first(2).  Read it back with:"' _n
    file write `fh' `"    *     infile using "`dictionary'", clear"' _n
    file write `fh' `"    * For a general comma-delimited CSV use import delimited + the do-file."' _n
    foreach v of local vars {
        local ty : type `v'
        local vl : variable label `v'
        * a dictionary quotes labels with "; embedded double quotes would break
        * the line, so soften them to single quotes (the do-file keeps them exact)
        local vl = subinstr(`"`macval(vl)'"', char(34), "'", .)
        if `"`macval(vl)'"' != "" {
            file write `fh' `"    `ty' `v' "`macval(vl)'""' _n
        }
        else file write `fh' `"    `ty' `v'"' _n
    }
    file write `fh' `"}"' _n
    file close `fh'
end


* ---------------------------------------------------------------------------
* Mata helpers for the relabel do-file.  Text written into a do-file is
* macro-expanded when that do-file runs, so a $ or a backtick in a label,
* note, or characteristic must be written as \$ or \` to survive.
* ---------------------------------------------------------------------------
version 16.0
mata:
string scalar _dd_esc(string scalar s)
{
    s = subinstr(s, char(96), char(92) + char(96))
    return(subinstr(s, char(36), char(92) + char(36)))
}

// load value label lname into locals __dd_nv, __dd_v#, __dd_t# (text cut
// to 2,000 characters; escaped for a do-file when esc != 0)
void _dd_vlload(string scalar lname, real scalar esc)
{
    real colvector    v
    string colvector  t
    real scalar       j

    st_vlload(lname, v, t)
    st_local("__dd_nv", strofreal(rows(v)))
    for (j = 1; j <= rows(v); j++) {
        st_local("__dd_v" + strofreal(j), strofreal(v[j], "%21.0g"))
        if (esc) st_local("__dd_t" + strofreal(j), _dd_esc(t[j]))
        else     st_local("__dd_t" + strofreal(j), substr(t[j], 1, 2000))
    }
}
end
