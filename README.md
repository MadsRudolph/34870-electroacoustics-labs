# 34870 Electroacoustics — labs

> **Overleaf (since 18 Nov 2026):** Overleaf is linked to the small repo `34870-labs-overleaf`, not to
> this one. Workflow: [`tools/OVERLEAF.md`](tools/OVERLEAF.md). The old Overleaf project is archived:
> never push from it, it deletes files here.

## Going to the lab? Copy `LabPC/`

`LabPC/` holds both lab GUIs ready to copy to the lab PC (MATLAB R2019b). Start with
[`LabPC/README.md`](LabPC/README.md).

Shared lab repo for the group (DTU 34870, autumn 2026). One folder per lab; every lab has
`report/` (LaTeX), `figures/` and its working files. The reports can be edited either in
Overleaf or locally; Overleaf goes through a small separate repo (see below).

| Lab | Topic | Period | Quiz deadline |
|---|---|---|---|
| A | Analogy circuits in LTspice | 8–20 Sep | 20 Sep |
| B | Scaled microphone measurement | 21–29 Sep | 5 Oct |
| C | Microphone calibration | 21–29 Sep | 5 Oct |
| D | Loudspeaker enclosures | 5–20 Oct | 26 Oct |
| E | Loudspeaker response | 5–20 Oct | 26 Oct |
| Project | Three-way loudspeaker, System D (`Project/`) | 26 Oct – 3 Dec | part 1: 8 Nov, part 2: 30 Nov |

Quizzes are answered individually; this repo is for the shared work behind them.

## New to Git? Start here

Open [the interactive GitHub Desktop guide](https://labs.madsrudolph.dev/).
It covers access, installation, cloning, a first practice commit, the daily workflow,
and Overleaf sync. Share that link with new teammates.

The guide source is `docs/getting-started.html`; hosting details are in
`docs/hosting/README.md`.

## Working with Overleaf

The Overleaf project is imported from the small private repo
[`MadsRudolph/34870-labs-overleaf`](https://github.com/MadsRudolph/34870-labs-overleaf), which holds
only the report sources and figures.
[Open the Overleaf project](https://www.overleaf.com/project/6afe0b5b02e06a98c0638cc2); ask Mads for an invitation. Edit the reports in
Overleaf; data and scripts stay in this repo.

`tools/overleaf_sync.py` moves the files between the two repos. The full workflow, step by step, is
in [`tools/OVERLEAF.md`](tools/OVERLEAF.md). In short:

- **Overleaf → here first:** push from Overleaf (*Menu → GitHub*), pull the small repo,
  `python3 tools/overleaf_sync.py import`, check `git diff`, commit here.
- **Here → Overleaf:** commit here, `python3 tools/overleaf_sync.py export`, commit + push the small
  repo, then *Pull GitHub changes into Overleaf*.
- Each lab has its own main document. In Overleaf set **Menu → Main document** to the report you are
  compiling, e.g. `Lab A/report/LabA_report.tex`.
- Don't edit the same file in both places between syncs; nothing merges it for you.

## Lab A layout

`KiCad/` eight KiCad 10 projects (ngspice) · `LTspice/` the same circuits as `.asc` + `.plt`,
generated and verified by `gen_ltspice.py --verify` · `sim/partN.py` rebuild, run and plot each
part · `figures/` every plot and schematic image the report uses · `results/` extracted numbers ·
`report/LabA_report.tex` the write-up. Figures are generated: if a number changes, rerun the
script rather than editing the image.
