# Loudspeaker project: three-way System D

Design a complete three-way loudspeaker from the units we measured in Lab D and Lab E:
tune the woofer box at low frequencies, model the crossovers in LTspice with the measured
data, build them (digital woofer/midrange crossover in the MiniDSP, passive midrange/tweeter
crossover on a filter board), and validate by listening. The brief is
`34870_Project_Guide_2026.pdf` on DTU Learn (Project).

**System D** is shared with Group 4 (book lab time together):
- Woofer box: **Scan-Speak 26W/8534G00** in the 88 L box (0.435 × 0.45 × 0.45 m), two telescopic
  vents (we measured the Ø 6.5 cm one). Data sheet in `../Lab D/datasheets/`.
- Mid/tweeter box: **DALI Spektor 2 (S/N 7446912 – L)**, 5¼″ mid + 25 mm soft dome. The box stays closed.
  (`Lab D/README.md` still guesses "DALI Concept"; the guide's appendix 2 says Spektor 2.)

Group 10: Louis Andrianne, Sophie Kimura, Mads Rudolph.

## Tasks and deadlines

| Task | What | Based on |
|---|---|---|
| 1 | Woofer box LF tuning: closed or vented, filling, vent mass (one, two or no vents), LTspice analogy validated against the near field | Lectures 7–8, Lab D |
| 2 | Crossover models in LTspice: Zi + TF of each unit, digital LPF/HPF (woofer/mid), passive LPF/HPF (mid/tweeter), summed response | Lecture 9, Lab D + E |
| 3 | Build: MiniDSP biquads + passive board, measure the system in the anechoic room (vents may be covered) | Lecture 9 |
| 4 | Listening test in the IEC room (booked all of November): procedure, subjects, questionnaire | Lecture 10 |
| 5 | Project quiz (individual) + demonstration | |

- **Project quiz part 1** (LTspice models + Lab D/E integration): **Sun 8 Nov 2026**
- **Project quiz part 2** (final results + discussion): **Mon 30 Nov 2026**
- **Demonstration** of all groups in room 019: **Thu 3 Dec 2026**. Bring the passive board and the digital coefficients; boxes and equipment are there; no formal presentation needed.
- Passive components: only the standard values in the guide's Appendix 1, no combining parts to get an in-between value.

Like the lab quizzes, the project quiz is individual and must be passed to sit the exam. This
repo holds the shared work behind it.

## Folders

```
Project/
  data/            LTspice text files Zi_{mid,tw}.txt, TF_{woof,mid,tw}.txt, TF30_*.txt
                   (export_systemD.m), csv/ = the same data as f,re,im for scripts
  ltspice/units/   Unit_woof/mid/tw.asc: one unit with our measured data, no filter
  ltspice/System_template.asc   Figure 1 wired up, filter slots empty (gen_templates.py)
  matlab/
    load_systemD.m     loads every Lab D/E file the project needs (see below)
    export_systemD.m   writes data/ from it
    course/            course files: DigitalCrossover.m, Matlab2LTspice.m, phaseunwrap.m
    course/ventedbox/  Lecture 8 ventbox.m (+ QB3, cheby2)
  ltspice/
    course/passive/    course example: one unit with Zi + TF, plus the example 2nd-order filter
    course/digital/    course example: woofer with two cascaded biquad E-sources
  figures/         plots for the report
  report/Project_report.tex   write-up skeleton (sections follow tasks 1–4)
```

## Start here

1. Work plan: `report/Project_todo.tex` (PDF next to it). It goes through the guide task by task,
   with a tick box and a name on every step.
2. The measured data is already exported for LTspice in `data/` (run `matlab -batch export_systemD`
   in `matlab/` to redo it, e.g. with another distance `d`).
3. Open `ltspice/units/Unit_mid.asc` (or `_tw`, `_woof`) and run it: that is each unit with our
   own Zi and TF, no filter. `ltspice/System_template.asc` is the whole of Figure 1 wired up with
   empty filter slots.
4. `python3 ltspice/gen_templates.py --verify` regenerates those files and checks them against
   the measurements in LTspice (needs LTspice under wine, as for the labs).

## Getting the measured data into LTspice

```matlab
cd Project/matlab
S = load_systemD;          % S.Zi.*, S.NF.*, S.TF.f, S.TF.on.*, S.TF.off30.*
addpath course
cd ../data
Matlab2LTspice(S.Zi.midrange.f, S.Zi.midrange.Z, 'Zi_mid', 0);        % impedance: no distance
Matlab2LTspice(S.TF.f, S.TF.on.midrange, 'TF_mid', 1, -1.15);         % TF: same d for all units
```

What feeds what:

| Need | File | In `S` |
|---|---|---|
| Zi midrange / tweeter (passive filter loads) | `Lab D/data/labD_midrange.mat`, `labD_tweeter.mat` | `S.Zi.midrange`, `S.Zi.tweeter` |
| Woofer T-S parameters | `labD_woofer_free.mat`, `labD_woofer_closed.mat` (+ `Lab D/matlab/analyse_labD.m`) | `S.Zi.woofer_free/closed` |
| Woofer in the box with one vent | `labD_vent_L160/L200/L240.mat` | `S.Zi.vent_L*` |
| Near field cone / vent (validate Task 1) | `labD_nf_cone_L*.mat`, `labD_nf_vent_L*.mat` | `S.NF.cone_L*`, `S.NF.vent_L*` |
| TF of the three units, 0° and 30° | `Lab E/data/labE_system_0.mat`, `labE_system_30.mat` (`H(:,1:3)` = woofer, mid, tweeter, vent plugged) | `S.TF.on.*`, `S.TF.off30.*` |

Notes on the data:
- Z already uses the 32.9 Ω series resistor and V_amp = 2·AI0 (see `Lab D/README.md`).
- The three Lab E units were measured in one run, so their relative phase is valid. `system_60`
  was not measured, and `labE_system_30_bad.mat` is a rejected run.
- Matlab2LTspice's distance `d`: `d = -1.15 m` flattens the Lab E phases (the lab convention used in
  the Lab E reference report). Use the same `d` for every unit, and never on Zi.
- Each exported file starts with a line naming its source and labels (`BiZin Vspkr …`,
  `BvTF Pout …`). Rename them per unit (e.g. `Vspkr_mid`, `Pout_mid`), because duplicate
  names break the simulation.
- The UMIK channel jumps about 20 dB above 18.4 kHz. Ignore the TF up there.

## Gotchas

- **`DigitalCrossover.m` makes Butterworth biquads, not Linkwitz–Riley.** n = 2 gives Q = 0.707,
  n = 4 gives Q = 0.541 and 1.307. For an LR4 sum, cascade two n = 2 Butterworth sections at the
  same f₀ (two E-sources) and check the summed response.
- **The passive example `.asc` (`ltspice/course/passive/… example filter.asc`) is drawn as a
  high-pass** even though the guide's Figure 2 calls it a 2nd-order low-pass. Check the topology
  before you copy it.
- **Lecture 9, slide 10:** the 10.06 µF in the worked example should be **10.61 µF**.
- `ventedbox/cheby2.m` shadows the Signal Processing Toolbox `cheby2`. Only add that folder to the
  path when you run `ventbox`.
- Keep the LTspice Y range under about 100 dB, or every curve looks flat.
- The tweeter is about 9 dB more sensitive than the midrange (Lab E), so the passive HPF needs an
  L-pad or a level compromise. Its resonance is about 1.45 kHz (Lab D), so keep the
  mid/tweeter crossover well above it (around 2.5–3 kHz).

## Solution branch (`project-solution`)

This branch carries a complete first design, every step documented in
`report/Project_report.tex` (the numbers in it are written by the scripts below, so rerunning them
updates the report). `main` keeps only the ready-to-use files, so the group can still work through
`report/Project_todo.tex` on its own and compare.

| Step | Run (from `Project/`) | Writes |
|---|---|---|
| Task 1: fit the woofer box to Lab D, tuning table | `python3 ltspice/task1/box_model.py --plots` | `figures/task1_*.png`, `report/results_task1.tex` |
| Task 1 in LTspice (plugged + 3 vent lengths, `.step`) | `python3 ltspice/task1/gen_box_ltspice.py --verify` | `ltspice/task1/Task1_WooferBox.asc` |
| Task 2: evaluate / re-optimise the crossover | `python3 design/xover.py [--optimise] --plots --export` | `design/design.json`, `figures/xover_*.png`, `data/dsp/`, `report/results_design.tex` |
| Task 2 in LTspice (whole system, verified against xover.py) | `python3 ltspice/gen_system.py --verify` | `ltspice/System_D_design.asc`, `data/Box_woof.txt` |
| Crossover Studio (interactive app) | `python3 app/build_app.py --test` | `app/index.html` |
| Report | `cd report && tectonic Project_report.tex` | `report/Project_report.pdf` |

The design lives in `design/design.json`. Crossover Studio exports the same format (Export → Design
file), so a design found by playing in the app can be pasted there and pushed through the Python and
LTspice pipeline.

**Crossover Studio** (`app/`) is the whole model in a browser page: box tuning, MiniDSP filters,
Appendix 1 passive parts, polarity and levels, with the response, phase/summing, amplifier load,
filter and woofer-box views updating as you change anything. It has an optimiser, a tolerance band, a
pinned reference curve for A/B comparison, and export of the MiniDSP text, the LTspice strings, the
parts list and the design file. `engine.js` is a port of `xover.py` and `box_model.py`;
`test_engine.mjs` checks it against them (`build_app.py --test`). Open `app/index.html` directly in a
browser; nothing needs installing.
