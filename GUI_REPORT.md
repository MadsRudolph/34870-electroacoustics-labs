# GUI report: `labgui`, the lab day in one window

Branch `gui-alt`, final commit **`e4df761`** (two commits on top of `27d3589`: `ab72ec4` the GUI and
the folder clean-up, `e4df761` the 11-Nov corrections: Out 1 gain -5.8 dB and the switchboard). Nothing was pushed,
`main` and the other worktree were not touched, nothing under `/run/media/` was touched.
Built and tested by Claude Fable 5.2 in one session, without helper agents (a helper that was
started by mistake at the very beginning was stopped before it changed any file).

All paths below are relative to `Project/Final design/lab-day/`.

## 1. How to start it

**In the lab (real measurements)**

1. Plug the UMIK into USB *before* starting MATLAB (chamber PC).
2. In MATLAB: `cd` to `...\Labs\Project\Final design\lab-day\kit`
3. Type `labgui`
4. Fill in *Settings of the day* (top right), click a step or a run on the left, do what
   *What to set up* says, press **Measure**.

Data go to `data/<date>/<step>.mat`. A repeat is saved as `_2`, `_3`; nothing is overwritten.

**At home (rehearsal, no hardware)**: `labgui demo`. Data go to `demo_data/<date>/` (git-ignored).
The code refuses to save demo data inside `data/`.

**Without the window**: `lab P`, `lab S`, ... as before, or open `kit/lab_run.m` and use Run
Section (one section per step, with what to set up). Tuesday's `matlab/project_run.m` and
`matlab/zinf_run.m` also still work.

## 1b. The 11-Nov corrections (commit `e4df761`)

**Out 1 gain is -5.8 dB** (the -10.3 was a misreading).

- Default for Thursday: `lab_setup.m` and `project_dims.m` say -5.8 (design -4.5).
- 10-Nov import: 0 dB for R1 tries 1 and 2, -5.8 dB for every later run. `data/project_*.mat`
  and `data/2026-11-10/*.mat` were regenerated; the measured data in them are bit-identical
  (checked with `isequaln` on `H` and `specn`), only the stored gain and the notes changed.
- Demo: the channels balance at -5.8; the "woofer loud" fault balances at -8.1.
- Also fixed in the log, the READMEs, the results write-up (PDF rebuilt), the legend of
  `fig_trust.png`, and the tests. `numbers.txt` is unchanged.

**Switchboard.** Every chamber step has an explicit state in `lab_plan.m` (new column `sw`):

| Step | ON | Step | ON |
|---|---|---|---|
| P1 / P2 / P3 (MiniDSP bypassed) | W / M / T | S1 / S2 / S3 | W / M+T / W+M+T |
| P2d / P3d (optional) | M / T | S4 / S5 | M / T |
| F0, F1, F2 | W+M+T | A1 / A2 / A3 | W / M+T / W+M+T |

- The texts no longer pull amplifier cables, mute in the MiniDSP or lift leads. They say what
  to set now and what to switch during each beep, e.g. "Switchboard: switch Woofer OFF, Mid ON,
  Tweeter ON."
- **In the GUI** each of the three instruction rows (NOW, BEEPS 1, BEEPS 2) shows the
  switchboard as three indicators: WOOFER / MID / TWEETER, green with "ON" or grey with "OFF".
  The row that applies right now is highlighted while measuring. Colours come from the palette
  and are checked for contrast in light and dark.
- F1 = Out 1 Invert ticked, F2 = tweeter + / - swapped at the board; the switchboard stays all ON.
- P2d / P3d are marked "OPTIONAL, only if the board can be bypassed".
- Z2 / Z3: "switch the tweeter / midrange OFF on the switchboard (or lift its lead)". The Zi
  steps have no indicators (text only).
- Advice, warnings, `lab_run.m` and `kit/README.md` were reworded the same way.

I looked at the indicators in both modes (`03_S_woofer_loud_light.png`, `08_measuring_light.png`,
`09_S_switchboard_dark.png`, `09_F_ok_dark.png`) and fixed two things: the ON/OFF word was clipped
(now on one line) and the longest instruction was cut off (shorter texts, slightly taller panel;
the full text is also in the tooltip).

## 2. The layout

![layout](Project/Final%20design/lab-day/kit/tests/screenshots/03_S_woofer_loud_light.png)

| Where | What |
|---|---|
| Header | day, group, a yellow **DEMO MODE** banner in demo, the data folder, the **Light / Dark** switch |
| Left: **Steps** | every step of `lab_plan.m` under its run heading, with a lamp (grey not done, green OK, orange CHECK, red BAD) and the time measured. Click a step = that step. Click a heading (P, S, F, A) = the whole run in one go. Ctrl+click = your own run of up to three chamber steps (e.g. S4 + S5 + S3; "all" is put last). |
| Middle top: **What to set up** | large text: NOW / DURING BEEPS 1 / DURING BEEPS 2, each with the **switchboard** drawn (WOOFER / MID / TWEETER, green ON or grey OFF), then one line with MiniDSP bypass/on, Out 1 and Out 2 gain, angle, amplifier. Numbers come from Settings. |
| Middle: **Measure** | one big button named after the run ("Measure S"). While measuring it is off, a bar fills, the text shows elapsed / expected time and the expected end time, and the instruction that applies right now is highlighted yellow ("BEEPS 1: SWITCH NOW for S2"). |
| Middle: **Verdict and what to do next** | OK / CHECK / BAD in colour, and plain sentences when not OK, e.g. "Woofer is 2.3 dB louder than mid+tweeter. Change Out 1 gain by -2.3 dB: set it to -8.1 dB in the MiniDSP app (it was -5.8), type -8.1 into Settings, then redo S1 + S2 + S3." When OK it says which run is next. |
| Middle bottom: **plots** (tabs) | *This run*: measured (solid) vs expected (dashed, level-matched), difference underneath; "Show run" lists every earlier run. *All runs today*: every "all" curve overlaid + difference to the first. *Impedance*: board and woofer, magnitude and phase. *Near field*: level and phase vs Lab D. |
| Right: **Settings of the day** | every field of `lab_setup.m`. Stored in each measurement and in `data/<date>/settings.json`, so they are back after a restart. A decimal comma is accepted. |
| Right: **The day's data** | Full dashboard, Export figures (PNG, always light), Copy data to ... (USB), Load manual runs ... |
| Right: **Log** | saved file names, warnings (clipping, small UMIK signal, AI0 DC offset) each followed by its FIX. Also written to `data/<date>/labgui_log.txt`. |
| Demo only | a list "what goes wrong in the next measurement": woofer loud, placement, not switched, quiet, clipping, dc offset, no umik, no beeps. |

Screenshots (made by `test_labgui` with `exportapp`, 1608 x 969), in `kit/tests/screenshots/`:

| File | Shows |
|---|---|
| `01_start_light.png` | empty start, all lamps grey |
| `02_P_ok_light.png` | run P measured, OK, advice "Next: S" |
| `03_S_woofer_loud_light.png` | run S, BAD, advice with the new Out 1 gain |
| `04_impedance_light.png`, `05_nearfield_light.png`, `06_all_runs_light.png` | the other three plot tabs |
| `07_error_no_umik_light.png` | course routine failed: NOT MEASURED + fix |
| `08_measuring_light.png` | taken *during* a measurement: progress bar, "SWITCH NOW", controls greyed |
| `09_S_switchboard_dark.png`, `09_F_ok_dark.png`, `10_impedance_dark.png`, `11_all_runs_dark.png` | dark mode (the first two show the switchboard indicators) |
| `12_manual_run_light.png` | Tuesday's `project_R1_split_0.mat` loaded as a manual run |
| `13_nov10_real_S_light.png` | the real 10-Nov data (run S) in the GUI |
| `14_nov10_real_F_dark.png`, `15_nov10_real_all_dark.png`, `16_nov10_real_nearfield_dark.png` | real 10-Nov data, dark |
| `17_real_mode_error_light.png` | real mode on this PC (no hardware): the real course routine's error caught |

I looked at the screenshots and fixed what was wrong: step texts cut off in the list (status now
comes right after the id, headings shortened), the header showing today's date for another day's
folder, an empty coloured bar when nothing is selected, run F being reordered (F0 must be first),
and plots squashed in a small window (a small window now scrolls instead).

## 3. Folders after the clean-up

Rule: the top of a folder holds only what you open, run or edit; what is only called is in
`core/`; tests are in `tests/`. Moves were done with `git mv` (history follows the files).

```
kit/        labgui.m  lab_run.m  lab.m  lab_setup.m  lab_plan.m  README.md
kit/core/   labpaths  lab_measure  lab_demo  lab_check  lab_judge  lab_worst  lab_advice
            lab_fix  lab_runs  lab_steps  lab_instructions  lab_timeline  lab_settings
            lab_convert  lab_view  lab_palette  lab_dash  lab_model  lab_smooth
kit/tests/  test_lab.m  test_labgui.m  screenshots/
matlab/     project_run.m  zinf_run.m  project_dims.m  README.md
matlab/core/   measure_project  compare_project  plot_project  measure_zinf  compare_zinf  zinf_calc
matlab/tests/  test_project.m  test_zinf.m
analysis/   import_labday  labday_to_kit  results_labday  pad_predict  README.md
```

Every folder path now comes from one helper, `kit/core/labpaths.m`. The only `'..'` left are the
single lines with which a test or analysis script finds that helper.
Docs updated for the new paths: `README.md`, `kit/README.md`, `LOG_2026-11-10.md`,
`results_2026-11-10/LabDay_Results.tex` (PDF rebuilt with tectonic). `guide/LabDay_Guide.tex`
needed no change: every path it names is still valid.

## 4. Test results

Run on the committed tree, MATLAB R2026a Update 5, Linux, no hardware:

| Test | Result |
|---|---|
| `kit/tests/test_lab` | **PASS**, 11 of 11 |
| `kit/tests/test_labgui` | **PASS**, 49 of 49 |
| `matlab/tests/test_project` | **PASS**, 11 of 11 |
| `matlab/tests/test_zinf` | **PASS**, 9 of 9 |

Each was also run from its own folder in a fresh MATLAB (so it finds its paths by itself), and
`test_project` + `test_zinf` once more the way section 0 of the Run Section files calls them.

What `test_labgui` does (demo mode, driven from code):

- start: all lamps grey, Measure off
- switchboard: P shows W / M / T for now, beeps 1, beeps 2; S shows W, M+T, W+M+T; F all ON;
  every chamber step has its state in the plan; no cable pulling left in the texts; indicator
  colours in light and dark; no indicators at the Zi station
- **P**: instructions, measure, `P.mat`, lamps green, advice "Next: S"
- wrong placement: P1 red, advice "placement differs from Lab E ... redo P"; P again -> `P_2.mat`
- **S** with the woofer 2.3 dB loud: lamps red, advice gives -8.1 dB; set it; S again -> green,
  the new gain is in the saved file, `S_2.mat`
- **F** (order F0, F1, F2), own run S4 + S5 + S3, run A with a state not switched in time (red)
- **Z1** without the series resistor: refused with the fix, nothing saved; with 32.9 ohm: green
- **Z4** with AI0 on a DC offset (noted in the log), **N1**, **N2**
- no UMIK, `beeps.wav` not found: caught, fix shown, nothing saved, window alive
- small UMIK signal, clipping: warning with fix
- while measuring: Measure is off and closing the window is ignored
- restart: settings, lamps and the colour mode come back
- dark and light: colours come from the palette; OK/CHECK/BAD and curve colours pass a contrast check
- export figures (light even when the GUI is dark), full dashboard, copy to a folder twice (second
  copy gets a new folder)
- manual runs: three of Tuesday's files load as S1+S2+S3, F0+F1+F2, N1; the originals are
  byte-identical afterwards and nothing was written next to them
- the real 10-Nov folder (a copy) opens: 7 runs, lamps S1 green, S2/S3 orange, F1 orange, N1 green
- real mode on this PC: the genuine course routine fails (no `beeps.wav` under that name on Linux)
  and the GUI shows the cd / copy `Beeps.wav` fix
- demo data are refused inside `data/`; `lab_run.m` has a section for every step

Also checked by hand:

- `analysis/results_labday` regenerates the 10-Nov figures; `numbers.txt` is identical to the
  committed one. `pad_predict` prints its table. `import_labday` and `labday_to_kit` produce
  content identical to the committed files (`isequaln`).
- `lab_dash` on `data/2026-11-10` draws all 8 tabs.
- `lab('P1', 'demo', true)` and `lab list` work from the command line.
- The regenerated PNG / MAT files differed only in bytes, so I restored the committed versions
  to keep the commit free of noise.

## 5. What I could not verify

- **Real hardware.** No UMIK, sound card, MiniDSP or NI card here. The real measuring path is the
  same call as before (`lab_measure` calls the course routines with the same arguments as the old
  `lab.m`), and `test_lab` exercises it with stand-in routines, but a real measurement from the
  GUI has not been made.
- **The progress bar during a real measurement.** The course routine blocks MATLAB with
  `recordblocking`. In demo the bar moves (screenshot 08). On the lab PC it may stand still
  until the routine returns. That is why the expected duration and the "done at" time are shown
  before it starts; the measurement itself is not affected. Check this first on Thursday.
- **Older MATLAB.** Only R2026a was available. I kept to components that exist in R2021a
  (uigridlayout, uitree, uiaxes, uiswitch, uitextarea, label WordWrap) and wrapped newer things in
  try/catch (`fig.Theme`, `PrettyPrint`, `scroll`, panel `BorderColor`, grid `Scrollable`).
  `exportapp` (R2020b) is only used for screenshots. Not run on an old release.
- **Windows.** Paths are built with `fullfile`; file dialogs (`uigetdir`, `uigetfile`) were not
  clicked through, only the code behind them was tested with folders given from code.
- **Dark mode on releases before R2025a**: the tab strip and scrollbars are drawn by MATLAB and
  may stay light there; everything else is coloured explicitly.
- **UMIK detection text at start** ("UMIK found: this is a chamber PC") depends on the Windows
  device name containing "Umik", as in the course routine. Not seen with a real UMIK.

- **The switchboard itself.** I have not seen it. I assumed three independent ON/OFF switches
  (woofer, midrange, tweeter) and that with the MiniDSP bypassed "woofer only" is made on it
  too, as the update says.

## 5b. Left as it was (tell me if these should change too)

- **The record of 10-Nov** still says the mutes were made by pulling the amplifier speaker
  cable (`LOG_2026-11-10.md`, the results write-up, the `mute_method` field and the "cable not
  back in time" note in `import_labday.m`). The update describes how the chamber works; it does
  not say that Tuesday's record is wrong, so I did not rewrite history on a guess.
- **`guide/LabDay_Guide.tex`** (the printed guide for 10-Nov) and the R1-R5 table in the lab-day
  `README.md` still describe Tuesday's plan: Out 1 -4.5 dB as the design value, states made by
  muting. The README's gain line now also names -5.8 dB as Thursday's default.
- **`matlab/project_run.m`** (Tuesday's Run Section file) still words its states as mutes.

## 6. Every change to existing behaviour

- **Files moved** (section 3). `cd kit; lab P` works as before. For Tuesday's scripts, each
  section of `project_run.m` / `zinf_run.m` now starts with `addpath core ../kit/core`; MATLAB's
  current folder must be `matlab/` (section 0 does the `cd`, as before).
- **`lab` uses the GUI's settings of that day.** If `data/<date>/settings.json` exists, `lab`
  uses those values on top of `lab_setup.m` and prints each one that differs. Without that file
  it behaves as before. `'set'` still overrides both.
- **`lab` has a new option** `'demo', true` (stand-in routines, data in `demo_data/`).
- **Instruction text**: "Out 1 gain as in lab_setup" and "lab_setup().vent_mm" are replaced by
  the actual numbers; each line reads `NOW  [P1] Placement: woofer: ...` (same content).
- **Missing series resistor**: the message now also names the GUI Settings.
- **Warnings from `lab`** carry the fix in the same line and have the id `lab:measure`.
- **`m.time`** in a saved run is now the moment the measurement finished (was: started).
- **A demo run** has an extra field `demo = true` in its file.
- **`lab_model`** has two new kinds (`chamber_raw`, `zinf_raw`) used by the demo; old calls unchanged.
- **`results_labday`, `pad_predict`, `import_labday`, `labday_to_kit`** live in `analysis/` and
  can be run from any folder.
- **New files written next to the day's data**: `settings.json` and `labgui_log.txt`. The
  dashboard ignores them (it reads `*.mat`).
- **`.gitignore`** in `lab-day/` ignores `demo_data/`.
- **11-Nov:** `lab_setup.m` default Out 1 gain -10.3 -> -5.8 dB. `lab_plan.m` has a new column
  `sw` and new setup texts (switchboard instead of cables / leads). The 10-Nov data files carry
  the corrected gain. `lab P` etc. print the switchboard state in their instructions.
- Verdict rules (`lab_check.m`), the dashboard and the course routines are unchanged.

## 7. Worth knowing

- Opening another day with `labgui('datadir', '../data/2026-11-10')` shows it with lamps and
  plots. A measurement made then would be saved into that folder; the log says so at start.
- The lamps show today's folder only. Manual runs appear in "Show run" and in the plots.
- A lamp also carries the run-level checks the step takes part in: balance colours S1 and S2,
  the sum check colours S3, the notch checks colour F1 and F2.
- The advice after an OK placement run mentions the board change planned for Thursday
  (Rp 3.3 -> 8.2 ohm) as an example; it is a reminder, not something the GUI checks.
- 18 screenshots (6 MB) are committed under `kit/tests/screenshots/`. Say if you would rather
  not have them in the repo.
