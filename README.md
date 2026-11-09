# datadictionary

Build an Excel codebook that lets a researcher size up a dataset at a glance: a
modern `descsave`.

Point `datadictionary` at the data in memory and it writes one row per
variable that puts the statistics, **% missing**, distinct count, common
values, variable and value labels, and stored `notes` side by side in a
`Variables` worksheet. On one screen you see each variable's type, how complete
it is, what its codes mean, and what values are common in it. Assembling that by
hand means running `describe`, `summarize`, `codebook`, and `tab` and holding the
four outputs in your head at once. Everything goes to the screen, to a
machine-readable `.dta`, and to the Excel workbook, including the
`char varname[source]` provenance stamp written by the companion `srctag`,
`combineall`, and `projectbuilder` tools (shown in the `srctag` column).

That works on any cross-sectional dataset. When a study runs in waves, point
`datadictionary` at the wave files (`files()` or `folder()`) and it stacks a
per-wave row for every variable and adds a `changed` column that flags a
variable whose label was reworded or whose categories shifted since the
previous wave. That is the signal that a variable may have stopped meaning what
it used to mean.
Change detection needs the original wave files: stitching waves into one file
destroys per-wave value labels, since after `append` only one definition per
label name survives. Run it before or alongside stitching to keep that
history.

In-memory mode documents the dataset in memory (optionally restricted by
`varlist`/`if`/`in`), and with `wave(varname)` documents a stitched file with
one codebook row per variable per wave. A variable that is all-missing within a
wave shows `pctmiss` 100 for that wave, meaning *absent or never answered*: a
stitched file cannot tell the two apart. The caller's data are preserved and
restored untouched in both modes. There are no dependencies beyond
Stata 16.0.

In-memory mode also writes a **relabel do-file** (`dofile()`), the classic
`descsave` idea, which re-applies every variable label, value label, format,
storage type, note, and characteristic after a dataset has been round-tripped
through CSV/Excel and another package (R, Python, a collaborator's
spreadsheet). It is `capture`-guarded and prints a re-ingestion receipt, so a
renamed or dropped column is skipped and reported, so nothing is silently
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

A CSV or Excel file holds the values but none of the labels, formats, notes, and
characteristics Stata attaches to them. `dofile()` writes those as runnable
code, so a dataset can leave Stata and come back fully re-dressed:

```stata
* 1. document + generate the relabel do-file
use staff_w1, clear
datadictionary, excel(staff_codebook) dofile(staff_relabel) replace

* 2. export the NUMERIC CODES (nolabel) so value labels reattach cleanly, and
*    quote text so a value with a line break stays in one row; then share
*    staff.csv + staff_codebook.xlsx with a collaborator
export delimited using staff.csv, nolabel quote replace

* 3. ...collaborator edits staff.csv in R / Python / Excel and returns it...

* 4. re-import and restore every label, format, note, and characteristic
import delimited using staff.csv, varnames(1) case(preserve) bindquote(strict) clear
do staff_relabel
```

The generated do-file sets `varabbrev off` and `capture`-prefixes every
command, so a column the collaborator renamed or dropped is **skipped, not
fuzzily relabeled**, and a *receipt* at the foot lists which expected variables
went missing and which extra columns appeared. Export with `nolabel`, which
writes numeric codes. If you export the text labels instead, the column comes
back as a string and the do-file cannot re-encode it. Export with `quote` and
import with `bindquote(strict)`: without them a free-text value that holds a
line break comes back split across extra rows.

The optional `dictionary()` writes a legacy free-format `infile` dictionary
(`.dct`) that reads a **whitespace-delimited** export in one typed step. A
`.dct` records storage type and variable label only, with no value labels,
notes, or characteristics, so the do-file is the complete tool. The dictionary
is there for teams that want one:

```stata
export delimited using staff.txt, delimiter(tab) nolabel quote replace
infile using staff.dct, clear
```

The Excel workbook contains an `Overview` sheet (sources, N and variable
count per wave, generation date, notes count); a `Variables` sheet, **the
codebook**, giving one row per variable (per variable-wave over time) with
statistics, **% missing**, distinct count, common values, labels, and notes
side by side; a `ValueLabels` sheet (label name, value, text); and, in files
mode, a
`Changes` sheet (one row per detected change: wave-pair, variable, change type,
before, after). Header rows are bold.

There is **no separate Missingness sheet**: `% missing` is a column in the
`Variables` codebook, so over time you read a variable's missingness down its
wave rows. Over-time modes also add a **`changed`** column that flags any
variable whose label was reworded or whose value-label categories shifted from
the previous wave. Treat that flag as a signal that the variable may have
stopped meaning what it used to mean. (A stitched panel keeps only one label set per variable, so in-memory
`wave()` mode leaves `changed` blank; run files mode over the original wave
files to populate it.)

## Syntax

```
in-memory:  datadictionary [varlist] [if] [in] [, wave(varname) shared_options]

files mode: datadictionary, files("w1.dta w2.dta ...") [wavenames("n1 n2 ...") shared_options]
            datadictionary, folder(dirpath) [pattern(str) wavenames("n1 n2 ...") shared_options]

shared_options: excel(filename) saving(filename) replace
                examples(#) top(#) nochars nonotes flow(filename)

in-memory only: dofile(filename) dictionary(filename) norecast
```

`excel()` and `examples()` share the stem `ex`: `ex()` is `excel()`, and
`examples()` must be spelled `exam()` or longer.

`flow(filename)` reads a journal written by the companion `surveymap` package
(a tab-separated file, one row per survey event) and appends two columns to the
codebook rows, matched on variable name: `pct_answered_sm`, the percent of
respondents in scope who answered the item, and `skipped_by_sm`, the skip logic
that routes respondents around it (for example `voted==0`). Codebook variables
absent from the journal get missing values; journal items absent from the
codebook are counted in one note line. A file that is not a surveymap journal
stops the command with error 459. It works in every mode.

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
  (value labels and changes, with % missing in the codebook sheet).
- Built-in `codebook` prints a rich per-variable report but stores no
  machine-readable product; `datadictionary` writes one (`saving()`) plus the Excel
  workbook, and tracks how the file changes across waves.

## Limitations in v1.0.x

- Change detection compares consecutive waves; a variable that skips a wave
  is counted as dropped and then added.
- Value-label text longer than 2,000 characters is truncated in the
  `ValueLabels` sheet and in the change-detection signatures; truncation is
  identical in every wave, so detection is unaffected.
- Example values and top categories are truncated to 2,000 characters per
  cell.
- A dataset with variables but 0 observations (an empty template) is refused
  with error 2000; add one placeholder row to document it.
- `dofile()` reattaches value labels only when the data was exported with
  `nolabel` (numeric codes); a column exported as its text labels comes back
  as a string it cannot re-encode.
- `dictionary()` produces a free-format `infile` dictionary, which is
  whitespace-delimited and records storage type and variable label only; for a
  general comma-delimited CSV round-trip with labels, notes, and chars, use
  `dofile()`.

## Changes

- **1.0.2 (2026-11-09):** works when the temp folder path contains a space
  (every call used to stop with `invalid 'dir'`, r(198)). The `srctag` column
  now reads `char varname[source]`, the stamp that `srctag`, `combineall`, and
  `projectbuilder` write; it used to read `char[srctag]`, which none of them
  writes, so the column was always empty. The round-trip recipe (README, help,
  and the header of every relabel do-file) exports with `quote` and imports
  with `bindquote(strict)`, so text with line breaks keeps its rows. The
  clickable open links expand a leading `~` and treat `\` paths as absolute,
  and wave names and output basenames split on `\` as well as `/`. An empty
  dataset is refused with its own message.
- **1.0.1 (2026-11-09):** text from the data is carried verbatim. A `$` or a
  backtick in a variable label, value-label text, note, characteristic
  (including `srctag`), string example value, or string wave value used to be
  macro-expanded: `Price in $USD` became `Price in ` on screen, in
  `saving()`, in the workbook, and in the `dofile()` relabel file (so running
  that file overwrote a good label with the mangled one), and a backtick in a
  string value stopped the command with r(132). The relabel do-file now
  escapes `$` and backticks, writes value labels itself instead of copying
  `label save` output, and restores notes through their characteristics,
  because the `note` command expands its text a second time. Value labels are
  read with `st_vlload` instead of `uselabel`, which expanded `$` the same way.

## License

MIT. See [LICENSE](LICENSE). Copyright (c) 2026 Eric A. Booth.

Support: eric.a.booth@gmail.com
