# datadictionary

Build an Excel codebook that lets a researcher size up a dataset at a glance —
a modern `descsave`.

Point `datadictionary` at the data in memory and it writes one row per
variable that puts the statistics, **% missing**, distinct count, common
values, variable and value labels, and stored `notes` side by side in a
`Variables` worksheet. Read one screen and you know each variable's type, how
complete it is, what its codes mean, and what it typically holds — the
meta-information you otherwise reconstruct by hand from `describe`, `summarize`,
`codebook`, and `tab`. Everything goes to the screen, to a machine-readable
`.dta`, and to the Excel workbook, and every value it reports (including the
`srctag` char written by the author's `combineall`/`projectbuilder` tools) is
one command away.

That works on any cross-sectional dataset. When a study runs in waves, point
`datadictionary` at the wave files (`files()` or `folder()`) and it stacks a
per-wave row for every variable and adds a `changed` column that flags a
variable whose label was reworded or whose categories shifted since the
previous wave — the signal that a variable may no longer mean the same thing.
Change detection needs the original wave files: stitching waves into one file
destroys per-wave value labels (after `append` only one definition per label
name survives), so run it before or alongside stitching to keep that history.

In-memory mode documents the dataset in memory (optionally restricted by
`varlist`/`if`/`in`), and with `wave(varname)` adds a per-wave missingness
grid for a stitched file. A variable that is all-missing within a wave is
reported as `absent`, meaning *absent or never answered* — the two cannot be
distinguished in a stitched file. The caller's data are preserved and
restored untouched in both modes. There are no dependencies beyond
Stata 16.0.

In-memory mode also writes a **relabel do-file** (`dofile()`) — the classic
`descsave` idea — that re-applies every variable label, value label, format,
storage type, note, and characteristic after a dataset has been round-tripped
through CSV/Excel and another package (R, Python, a collaborator's
spreadsheet). It is `capture`-guarded and prints a re-ingestion receipt, so a
renamed or dropped column is skipped and reported rather than silently
mislabeled. An optional `dictionary()` writes a legacy `infile` dictionary
(`.dct`) for a typed whitespace-delimited read.

## Install

From GitHub:

```stata
net install datadictionary, from("https://raw.githubusercontent.com/ericabooth/datadictionary-stata-public/main/") replace force
help datadictionary
```

## Quick start

```stata
* CROSS-SECTIONAL (the simple case): one dataset -> one codebook row per
* variable, statistics and % missing side by side, to screen + .dta + Excel
sysuse auto, clear
datadictionary
datadictionary, excel(auto_codebook) saving(auto_codebook) replace
return list

* a varlist and an if restriction work as usual
datadictionary price mpg rep78 foreign if foreign == 1, excel(imports) replace

* OVER TIME: three wave files -> per-wave rows + change detection; the Variables
* sheet gains a "changed" column flagging any variable whose label or category
* set shifted from the previous wave
datadictionary, files("staff_w1.dta staff_w2.dta staff_w3.dta") ///
    wavenames("2019 2021 2023")                           ///
    excel(staff_codebook) saving(staff_codebook) replace

* the same, taking every matching file in a folder (sorted by filename)
datadictionary, folder("waves") pattern("staff_*.dta") excel(staff_codebook) replace

* an already-stitched panel: per-wave statistics and missingness
datadictionary, wave(wave) excel(stitched_codebook) replace

* portability: also write a do-file that re-applies labels/formats/notes/chars
* after a CSV round-trip, and a dictionary for a typed infile read
datadictionary, excel(auto_codebook) dofile(auto_relabel) dictionary(auto) replace
```

After each run, `datadictionary` prints clickable links to open the workbook,
the other outputs, and their containing folder.

### Round-tripping data through R, Python, or Excel

A CSV or Excel file carries values but not the labels, formats, notes, and
characteristics Stata attaches to them. `dofile()` writes those as runnable
code, so a dataset can leave Stata and come back fully re-dressed:

```stata
* 1. document + generate the relabel do-file
use staff_w1, clear
datadictionary, excel(staff_codebook) dofile(staff_relabel) replace

* 2. export the NUMERIC CODES (nolabel) so value labels reattach cleanly,
*    then share staff.csv + staff_codebook.xlsx with a collaborator
export delimited using staff.csv, nolabel replace

* 3. ...collaborator edits staff.csv in R / Python / Excel and returns it...

* 4. re-import and restore every label, format, note, and characteristic
import delimited using staff.csv, varnames(1) case(preserve) clear
do staff_relabel
```

The generated do-file sets `varabbrev off` and `capture`-prefixes every
command, so a column the collaborator renamed or dropped is **skipped, not
fuzzily relabeled**, and a *receipt* at the foot lists which expected variables
went missing and which extra columns appeared. Export with `nolabel` (numeric
codes) — exporting the text labels instead turns the column into a string the
do-file cannot re-encode.

The optional `dictionary()` writes a legacy free-format `infile` dictionary
(`.dct`) that reads a **whitespace-delimited** export in one typed step. It
carries storage type + variable label only (no value labels, notes, or chars),
so the do-file is the complete tool; the dictionary is there for teams that
want one:

```stata
export delimited using staff.txt, delimiter(tab) nolabel quote replace
infile using staff.dct, clear
```

The Excel workbook contains an `Overview` sheet (sources, N and variable
count per wave, generation date, notes count), a `Variables` sheet — **the
codebook**: one row per variable (per variable-wave over time) with statistics,
**% missing**, distinct count, common values, labels, and notes side by side —
a `ValueLabels` sheet (label name, value, text), and, in files mode, a
`Changes` sheet (one row per detected change: wave-pair, variable, change type,
before, after). Header rows are bold.

There is **no separate Missingness sheet**: `% missing` is a column in the
`Variables` codebook, so over time you read a variable's missingness down its
wave rows. Over-time modes also add a **`changed`** column that flags any
variable whose label was reworded or whose value-label categories shifted from
the previous wave — a signal that the variable may no longer mean the same
thing. (A stitched panel keeps only one label set per variable, so in-memory
`wave()` mode leaves `changed` blank; run files mode over the original wave
files to populate it.)

## Syntax

```
in-memory:  datadictionary [varlist] [if] [in] [, wave(varname) shared_options]

files mode: datadictionary, files("w1.dta w2.dta ...") [wavenames("n1 n2 ...") shared_options]
            datadictionary, folder(dirpath) [pattern(str) wavenames("n1 n2 ...") shared_options]

shared_options: excel(filename) saving(filename) replace
                examples(#) top(#) nochars nonotes

in-memory only: dofile(filename) dictionary(filename) norecast
```

See `help datadictionary` for details on every option.

## Stored results

`datadictionary` stores the following in `r()`:

| Result        | Meaning                                                              |
| ------------- | -------------------------------------------------------------------- |
| `r(nvars)`    | number of codebook rows: variables documented (variable-waves in files mode) |
| `r(nchanges)` | number of changes detected across waves (0 outside files mode)        |
| `r(xlsx)`     | path of the Excel workbook written (only with `excel()`)              |
| `r(dta)`      | path of the codebook dataset written (only with `saving()`)           |
| `r(dofile)`   | path of the relabel do-file written (only with `dofile()`)            |
| `r(dct)`      | path of the dictionary written (only with `dictionary()`)             |

## Related work

- Roger Newson's `descsave` (SSC) exports variable-level attributes to a
  dataset or do-file; `datadictionary` adds over-time change detection, missingness
  patterns, example values, and the notes/chars/srctag harvest.
- Kishor Das's `codebookout` (SSC) writes a one-dataset codebook to Excel;
  `datadictionary` adds the multi-wave file comparison and the multi-sheet workbook
  (value labels, changes, missingness).
- Built-in `codebook` prints a rich per-variable report but stores no
  machine-readable product; `datadictionary` writes one (`saving()`) plus the Excel
  workbook, and tracks how the file changes across waves.

## Limitations in v1.0.0

- Change detection compares consecutive waves; a variable that skips a wave
  is counted as dropped and then added.
- Value-label text longer than 80 characters is truncated in the
  `ValueLabels` sheet and in the change-detection signatures (a `uselabel`
  limit); truncation is identical in every wave, so detection is unaffected.
- Example values and top categories are truncated to 2,000 characters per
  cell.
- `dofile()` reattaches value labels only when the data was exported with
  `nolabel` (numeric codes); a column exported as its text labels comes back
  as a string it cannot re-encode.
- `dictionary()` produces a free-format `infile` dictionary, which is
  whitespace-delimited and carries storage type + variable label only; for a
  general comma-delimited CSV round-trip with labels, notes, and chars, use
  `dofile()`.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Eric A. Booth.

Support: eric.a.booth@gmail.com
