# 34870 Electroacoustics — labs

Shared lab repo for the group (DTU 34870, autumn 2026). One folder per lab; every lab has
`report/` (LaTeX), `figures/` and its working files. The repo is linked to an Overleaf
project through Overleaf's GitHub synchronisation, so the reports can be edited either in
Overleaf or locally.

| Lab | Topic | Period | Quiz deadline |
|---|---|---|---|
| A | Analogy circuits in LTspice | 8–20 Sep | 20 Sep |
| B | Scaled microphone measurement | 21–29 Sep | 5 Oct |
| C | Microphone calibration | 21–29 Sep | 5 Oct |
| D | Loudspeaker enclosures | 5–20 Oct | 26 Oct |
| E | Loudspeaker response | 5–20 Oct | 26 Oct |

Quizzes are answered individually; this repo is for the shared work behind them.

## Working with Overleaf

- In Overleaf: **Menu → GitHub** shows *Pull GitHub changes into Overleaf* and *Push Overleaf
  changes to GitHub*. The sync is manual in both directions: push from Overleaf when you stop
  editing, pull into Overleaf after someone has pushed from a PC.
- Each lab has its own main document. In Overleaf set **Menu → Main document** to the report
  you are compiling, e.g. `Lab A/report/LabA_report.tex`.
- Locally: `git pull`, edit, build with `tectonic "Lab A/report/LabA_report.tex"` (or latexmk),
  commit, `git push`, then pull into Overleaf.
- Do not edit the same file in both places between syncs; Overleaf will not merge conflicts
  for you.

## Lab A layout

`KiCad/` eight KiCad 10 projects (ngspice) · `LTspice/` the same circuits as `.asc` + `.plt`,
generated and verified by `gen_ltspice.py --verify` · `sim/partN.py` rebuild, run and plot each
part · `figures/` every plot and schematic image the report uses · `results/` extracted numbers ·
`report/LabA_report.tex` the write-up. Figures are generated: if a number changes, rerun the
script rather than editing the image.
