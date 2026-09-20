# Lab B — Microphone scattering (scaled-up mock-up in the anechoic chamber)

Quiz (Lab B + C together, individual): deadline **Mon 5 Oct 2026**. Brief: `34870_Lab_B_CylinderScattering_E2026.pdf` on DTU Learn.

| Folder | What |
|---|---|
| `matlab/course/` | The course measurement routine and the UMIK correction files, unchanged (from `34870 - Lab B.zip`). |
| `matlab/measure_labB.m` | Lab-day wrapper: one call per measurement, uses the parameters from the lab sheet, saves `data/labB_<tag>.mat` straight away (never overwrites) and shows signal vs. noise floor. |
| `matlab/process_labB.m` | At home: normalise with the no-mock-up reference, overlay the BEM model, scale to 1", 1/2", 1/4", 1/8" microphones, optional 1/r check. Writes `figures/`. |
| `bem/run_bem.m` | Runs the course BEM model `CylinderPlaneWave` for 0–180° and both back-end shapes → `bem_results.mat` / `.csv`. The 106 MB package is unpacked into `bem/package/` (gitignored; unzip `BEM_FreeField.zip` from DTU Learn there). |
| `data/` | Raw measurements from the lab. |
| `report/` | LaTeX report (Overleaf). |

## In the lab

Copy `matlab/` to the lab PC (it has no internet; bring it on a stick or laptop). Connect the UMIK **before** starting MATLAB. Then, with loudspeaker and UMIK fixed for the whole series:

```matlab
measure_labB('nomockup', '708-03xx')     % reference WITHOUT the mock-up (do it first and again at the end)
measure_labB('ang000',   '708-03xx')     % mock-up face almost touching the UMIK, 0 deg
measure_labB('ang045',   '708-03xx')
measure_labB('ang090',   '708-03xx')     % more angles if there is time: ang030, ang060, ...
```

Optional Part 0 (before the mock-up series, because it moves the microphone): `measure_labB('dist100cm', …)`, `measure_labB('dist200cm', …)`.

Write down: mock-up diameter and length, loudspeaker–microphone distance, UMIK serial number, amplifier setting.
