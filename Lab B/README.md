# Lab B — Microphone scattering (scaled-up mock-up in the anechoic chamber)

Quiz (Lab B + C together, individual): deadline **Mon 5 Oct 2026**. Brief: `34870_Lab_B_CylinderScattering_E2026.pdf` on DTU Learn.

| Folder | What |
|---|---|
| `matlab/course/` | The course measurement routine and the UMIK correction files, unchanged (from `34870 - Lab B (2).zip`, the 21-Sep re-upload: devices are now found as `Line In` / `Speakers` on the internal sound card, not the USB card). |
| `matlab/labB_devices.m` | Run first on the lab PC: prints the audio devices and which three the course routine will pick. If one is NaN, fix the `contains` tests before measuring. |
| `matlab/measure_labB.m` | Lab-day wrapper: one call per measurement, uses the parameters from the lab sheet, saves `data/labB_<tag>.mat` straight away (never overwrites) and shows signal vs. noise floor. |
| `matlab/import_group_files.m` | **What was actually needed on 22-Sep:** the group used the course script `labB.m` on the lab PC, so the files in `data/Lab B master group 10/` hold only `h`. This rebuilds the frequency axis from the multitone generator and writes the `labB_<tag>.mat` files below (originals untouched). Run once, then `process_labB`. |
| `matlab/process_labB.m` | At home: normalise with the no-mock-up reference, overlay the BEM model, scale to 1", 1/2", 1/4", 1/8" microphones, optional 1/r check. Writes `figures/`. |
| `bem/run_bem.m` | Runs the course BEM model `CylinderPlaneWave` for 0–180° and both back-end shapes → `bem_results.mat` / `.csv`. The 106 MB package is unpacked into `bem/package/` (gitignored; unzip `BEM_FreeField.zip` from DTU Learn there). |
| `data/` | Raw measurements from the lab: `Lab B master group 10/` as copied from the lab PC, `labB_*.mat` derived from them, `labB_log.md` with every setting and what was not recorded. |
| `report/` | LaTeX report (Overleaf). |

## In the lab

Copy `matlab/` to the lab PC (it has no internet; bring it on a stick or laptop). Connect the UMIK **before** starting MATLAB. Then, with loudspeaker and UMIK fixed for the whole series:

```matlab
labB_devices                             % Umik, Line In, Speakers all found?
measure_labB('nomockup', '708-03xx')     % reference WITHOUT the mock-up (do it first and again at the end)
measure_labB('ang000',   '708-03xx')     % mock-up face almost touching the UMIK, 0 deg
measure_labB('ang045',   '708-03xx')
measure_labB('ang090',   '708-03xx')     % more angles if there is time: ang030, ang060, ...
measure_labB('nomockup_end', '708-03xx') % reference again: proves nothing moved
```

A bad run: just call it again with the same tag. Nothing is overwritten (`_2`, `_3`, ...) and `process_labB` takes the newest repeat of each tag.

Optional Part 0 (before the mock-up series, because it moves the microphone): `measure_labB('dist100cm', …)`, `measure_labB('dist200cm', …)`.

Write down: mock-up diameter and length, loudspeaker–microphone distance, UMIK serial number, amplifier setting.

## What happened on 22-Sep-2026

Measured at 2.8 m (the reference file is called `no_mockup_1.8m`: a typo, the 1/r check
gives −9.6 dB = 2.8 m). Seven angles 0–90° in 15° steps, reference after the series, then
Part 0 at 1.4 m and 0.93 m. The UMIK tip sat 2–3 cm in front of the face: clean
free-field correction up to 2 kHz, and above that the BEM's "3 cm field point" curve
(notch at 4 kHz). Mock-up diameter was not taped; `D_mockup` stays at the nominal 250 mm.
Full story: vault `Labs/Lab B - Runthrough.md`, report `report/LabB_report.tex`.
