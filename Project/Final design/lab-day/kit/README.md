# Lab kit: one command, a graph after every measurement

Made after 10-Nov, where the section scripts were hard to follow and we wanted to see a graph at
every stage. In MATLAB, `cd` into this folder on the lab PC and use `lab`.

```
lab                 dashboard of everything measured today + the step list
lab P               placement check: woofer, mid, tweeter (MiniDSP BYPASSED) vs Lab E, one run
lab P1              one step on its own
lab S               the system: woofer / mid+tw / all in one run (balance + sum check)
lab S4, lab S5      midrange only, tweeter only (MiniDSP on)
lab F               polarity flips (all / woofer inverted / tweeter swapped)
lab A               30 deg: woofer / mid+tw / all
lab Z1 ... Z4       impedance at the Zi station (board, mid branch, tweeter branch, woofer)
lab N1, lab N2      near field cone / vent
lab list            the step list, with what is done
```

Before every measurement a box says exactly what to set up (which cable to pull, which lead to
lift, MiniDSP bypass or on). Press **Measure**. In a run of several steps, switch during the beeps
as the box says. After the measurement:

- the data go to `../data/<date>/<step>.mat` (repeats get `_2`, `_3`, never overwritten);
- the dashboard opens on **Latest**: measured (solid) vs expected (dashed, shifted by the fitted
  level), the difference underneath, and a verdict in the title: **green OK / orange CHECK / red BAD**;
- the other tabs always show everything of the day: Plan (every step and its verdict), Placement,
  System (every "all" run overlaid + the phase between the two channels), Flips, 30 deg,
  Impedance, Near field. Each tab is saved as `../data/<date>/figures/<tab>.png`.

What "OK" means: shape within 1.5 dB rms of the expectation in the step's band; woofer vs
mid+tw within 1 dB (else it says how much to change the Out 1 gain); sum check within 0.5 dB;
flip notches at least 10 dB deep near the predicted frequency; board impedance within 1 dB of
the model; woofer fb within 1.5 Hz of Lab D; near field within 1 dB of Lab D over 80 % of 10-200 Hz.

## Files

| File | What |
|---|---|
| `lab_setup.m` | **edit at the start**: Out 1 gain (-10.3 dB on 10-Nov), amplifier, vent (160 mm), series R, UMIK |
| `lab_plan.m` | every step: one line each (add a step = add a line) |
| `lab.m` | the command: instructions, measurement, save, verdict, dashboard |
| `lab_check.m` | the verdicts |
| `lab_dash.m` | the dashboard, always redrawn from the files of the day |
| `lab_model.m` | the expected curves (`../model/*.csv`, Lab D data) |
| `test_lab.m` | offline test with stand-ins for the course routines: must print PASS |

The expected curves come from `../model_curves.py` (Lab E/D data through our filters, vent plugged).
`byp_*` = MiniDSP bypassed, through the board; `dir_*` = the unit wired straight to the amplifier,
which is exactly the Lab E measurement. The 10-Nov runs are converted into this format in
`../data/2026-11-10/` (`../matlab/labday_to_kit.m`), so `lab_dash('../data/2026-11-10')` shows that day.
