# Task: build a MATLAB lab GUI for our loudspeaker measurements

## Who we are and what happened
We are a group of three students in DTU course 34870 Electroacoustics (Group 10, loudspeaker
"System D": a Scan-Speak woofer in an 88 L vented box with a digital LR4 crossover at 325 Hz in a
MiniDSP, and a DALI mid/tweeter box with a passive crossover board). We measure the built system in
the course's project lab:
- **Anechoic chamber**: UMIK-1 USB mic + sound card. The sound card output goes through the MiniDSP
  to a stereo amplifier (ch. 1 = woofer, ch. 2 = passive board -> mid + tweeter). The course routine
  `meas_mag_spec2_SoundCard_LabE` measures 1-3 "states" per call with ~30 s of beeps between them
  (you switch cables/leads during the beeps; states within one call share a phase reference).
- **Zi/Nfield station** (NI-4431 card, course routine `meas_mag_spec2_LabD`): impedance through a
  ~33 ohm series resistor, and near-field pressure with the resistor shorted.

On Tuesday we couldn't work out how to use our section-based MATLAB scripts in the lab: they print
to the console, and we couldn't tell which files to run or edit. We lost an hour. Since then a small
command-line kit has been written. **We now want a MATLAB GUI on top of it that makes the lab day
easy for three people standing at a lab PC.** The next session is Thursday 12-Nov-2026.

## Where you work
This folder, `/home/mads/Labs-gui-alt`, is a git worktree of our labs repo on the branch `gui-alt`
(created from commit 27d3589). Work only inside this folder and commit only to `gui-alt`. Do NOT
touch `/home/mads/DTU/5. Semester/Electroacoustics/Labs` (another implementation is being built
there at the same time), never touch `main`, never push, and don't touch anything under
`/run/media/` (USB stick).

## What exists (read all of it first)
Everything is in `Project/Final design/lab-day/`:
- `kit/`: the CLI kit.
  - `lab.m` is the entry point: shows the instructions -> measures -> saves `../data/<date>/<label>.mat`
    (never overwrites) -> gives a verdict -> opens the dashboard.
  - `lab_plan.m`: the step catalogue (id, run group, station, model curve, angle, MiniDSP
    bypass/on, judging band, title, setup text). Groups: P = placement check vs Lab E with the
    MiniDSP bypassed, S = system, F = polarity flips, A = 30 deg, Z = impedance, N = near field.
  - `lab_setup.m`: session settings (UMIK serial, amp volume, Out 1 gain -10.3 dB, Out 2 0 dB, vent
    160 mm, series R, Nexus V/Pa, temperature, notes). `lab` accepts a `'set'` struct to override them.
  - `lab_check.m`: verdicts OK/CHECK/BAD per step plus run-level checks: 'bal' (woofer vs mid+tw
    within +-1 dB, and how much to change the Out 1 gain), 'sum' (woofer+midtw = all), 'F1n'/'F2n'
    (polarity-flip notch depth and frequency).
  - `lab_model.m`: the expected curves from `../model/*.csv` and the Lab D data.
  - `lab_dash.m`: a figure dashboard with tabs. `lab_smooth.m`: smoothing.
  - `test_lab.m`: an offline test with stand-in course routines; it must print PASS.
- `matlab/`: Tuesday's scripts: `project_run.m`, `zinf_run.m` (Run Section files),
  `measure_project`, `compare_project`, `plot_project`, `project_dims`, `measure_zinf`,
  `compare_zinf`, `zinf_calc`, `test_project`, `test_zinf`, and the analysis scripts
  `import_labday`, `labday_to_kit`, `results_labday`, `pad_predict`.
- `data/2026-11-10/`: Tuesday's real runs in the kit format. Use them to develop the GUI's views.
- `model/`, `model_curves.py`: the expected curves. `results_2026-11-10/LabDay_Results.pdf`:
  Tuesday's results and the Thursday plan (`lab P` first, swap Rp 3.3 -> 8.2 ohm, `lab S`, `S4`,
  `S5`, `F`, `A`, repeat `S`; Zi: `Z1`-`Z4`, `N1`, `N2`).
- The course routines: `Lab E/matlab/course/meas_mag_spec2_SoundCard_LabE.m` and
  `Lab D/matlab/course/meas_mag_spec2_LabD.m` (do not modify them).

## Requirements
1. **The GUI**: a programmatic `uifigure` app with a single entry point `labgui.m` (no App Designer
   .mlapp, so it diffs in git).
   - **Steps panel**: every step, grouped by run, with a status lamp (grey not done, green OK,
     orange CHECK, red BAD) and the time measured. Select one step, or a whole group for multi-step runs.
   - **Instructions**: large and plain. What to set up now, what to switch during beep 1 and beep
     2, MiniDSP bypass/on, the gains, the angle. One big **Measure** button with progress, elapsed
     and expected time. It is disabled while measuring.
   - **Embedded plots**: measured vs expected (level-matched) with the difference underneath, the
     verdict in colour, and **what to do next** in plain words when not OK (e.g. "change Out 1 gain
     by -2.3 dB", "placement differs from Lab E: move the box/mic and redo P"). Earlier runs can be
     viewed, there is an overlay of every 'all' run of the day, and there are impedance and
     near-field views.
   - **Settings panel**: edit the `lab_setup` fields in the GUI. They are stored with every
     measurement and persist for the session (survive a restart).
   - **Log pane**: saved file names and warnings (clipping, small UMIK signal, AI0 DC offset),
     with fixes.
   - **Buttons**: open the full dashboard, export the day's figures, copy the day's data to a
     chosen folder (USB).
   - **Load manual runs**: show measurements made with Tuesday's scripts (`data/project_*.mat`,
     `data/zinf_*.mat`) in the GUI by converting them on the fly, as `labday_to_kit.m` does. Never
     modify the originals.
   - **Demo/offline mode** (`labgui('demo')`): stand-in course routines (as in `test_lab.m`:
     expected curves, a level shift, random latency, a little noise) so we can rehearse the whole
     flow at home. Demo data goes to a separate folder and never mixes with real data.
   - **Robustness**: course-routine failures (no UMIK, `beeps.wav` not found -> the fix is to `cd`
     into the course folder or copy `Beeps.wav`) are caught and shown with the fix. The app never
     dies, and data are never overwritten.
   - **Light/dark mode**: a Light/Dark switch in the GUI (default light, remembered in the session
     settings). It covers everything: panels, lists, text, buttons, lamps (OK/CHECK/BAD readable on
     both backgrounds) and the embedded plots (axes background, grid, ticks, labels, legend, curve
     colours that stay distinct on dark). The uifigure `Theme` property only exists from R2025a, so
     set the colours explicitly from one palette function and only additionally set `fig.Theme`
     inside try/catch. Exported figures for reports stay light. `test_labgui` saves a screenshot in
     both modes.
2. **Manual use must keep working**: Tuesday's Run Section scripts and the CLI (`lab P`, `lab S`,
   ...) keep working. Also add a Run Section file `kit/lab_run.m` with one section per step and a
   comment saying what to set up.
3. **Clean up the folders** with one rule: a folder's top level holds only files you open, run or
   edit; everything that is only called goes in a `core/` subfolder (not MATLAB `private/`), and
   tests go in `tests/`. For example: `kit/` (labgui, lab_run, lab, lab_setup, lab_plan) +
   `kit/core/` + `kit/tests/`; `matlab/` (project_run, zinf_run, project_dims) + `core/` +
   `tests/`; `analysis/` for the after-the-lab scripts.
   - Use `git mv`.
   - Fix every relative path. Prefer one helper (e.g. `core/labpaths.m`) over counting `..`.
   - Give each folder a 5-line README: open/run these, edit these, don't touch `core/`.
   - Update the docs (lab-day README, kit README, log, results .tex) for the new paths.
4. **Tests**:
   - `test_lab`, `test_project`, `test_zinf` must still PASS.
   - Add `test_labgui` that builds the app in demo mode, drives it programmatically through at
     least P, S, F and Z1, and checks lamps, verdicts and files.
   - Save screenshots with `exportapp`, look at them, and fix layout problems.
   - `results_labday` must still regenerate the 10-Nov figures, and the dashboard on
     `data/2026-11-10` must still work.
5. **Compatibility**: the lab PCs may run an older MATLAB than this PC (R2026a). Stick to uifigure
   features from R2021a or earlier, or guard newer ones with try/catch. Use the light theme.
6. **Environment**:
   - Linux (Arch, Hyprland). MATLAB headless: `matlab -batch "..." < /dev/null`. `DISPLAY` is
     normally set, so uifigure can render.
   - No hardware is attached here, so everything is tested with stand-ins.
   - Commit messages like a developer writes them, with no AI attribution or co-author lines.

## Deliver
Write `GUI_REPORT.md` in this folder (not committed) with:
- The layout, with the screenshot paths.
- How to start it in the lab and in demo mode.
- The test results.
- What you could not verify.
- Every change to existing behaviour.
- The final commit hash on `gui-alt`.

## Update (11-Nov): two corrections from the user
1. **Out 1 gain**: on 10-Nov the MiniDSP Out 1 (woofer) was at **0 dB** in R1 try 1 and try 2 and was then
   set **to -5.8 dB** (not -10.3; that number was a misreading). The default for Thursday is
   `out1_gain = -5.8` (design -4.5; the lab chain's woofer path is ~1.3 dB hotter). Fix it everywhere
   in this branch: `lab_setup`, the demo stand-ins (-5.8 is balanced), the 10-Nov data import
   (0 dB for tries 1-2, -5.8 after), the log, the READMEs, GUI texts and tests.
2. **Switchboard**: in the chamber the units are selected with a **switchboard** where woofer, midrange
   and tweeter can each be switched ON/OFF (the same as in Lab E). The states are made that way, not by
   pulling amp cables, not by the MiniDSP mute and not by lifting leads. Give every chamber step an
   explicit switchboard state (P1 W only, P2 M only, P3 T only with the MiniDSP bypassed; S1 W, S2 M+T,
   S3 W+M+T, S4 M, S5 T; F0-F2 all on (F1 = Out 1 Invert, F2 = tweeter swapped at the board); A like S;
   P2d/P3d optional, only if the board can be bypassed). The texts say what to switch on/off now and
   during each beep. **Show the switchboard visually in the GUI**: Woofer / Mid / Tweeter ON/OFF
   indicators for the state to set now, plus the states after beeps 1 and 2, in both themes. Z2/Z3 at
   the Zi station: switch the tweeter / midrange off on the switchboard (or lift its lead).
Update the tests, look at screenshots of the switchboard indicators in light and dark, commit to
`gui-alt`, and update GUI_REPORT.md.
