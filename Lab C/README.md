# Lab C — Microphone calibration (calibrators + electrostatic actuator)

Measured **Tue 29 Sep 2026**, room 026, building 354, Group 10. Quiz (Lab B + C together, individual): deadline **Mon 5 Oct 2026**.

| Folder | What |
|---|---|
| `raw data/` | **Untouched** copy of the lab-PC MATLAB folder (data, scripts as they were run, `.asv` autosaves, course routines, the brief). Read-only — never edit, never save into it. |
| `matlab/` | The clean analysis. One commented document per part of the brief; each loads the raw files into a struct (so nothing overwrites anything) and writes only to `matlab/results/` and `figures/`. |
| `matlab/course/` | The course routines, for reference. |
| `figures/` | The six figures the analysis produces. |
| `ltspice/` | `gen_labC_ltspice.py` → `LabC_CondenserMics.asc`, the three-domain model with the measured `fs`/`Q`. `--verify` checks it against the closed form, `--export` writes `matlab/results/ltspice_labC.csv` for `part4_model.m`. |
| `report/` | `LabC_report.tex` = the group's report (to be written by us). `LabC_reference.tex/.pdf` = a complete worked version to check against. |

## Running the analysis

```matlab
cd matlab
run_all                      % or the parts one by one, in order
```

| Script | Does |
|---|---|
| `part1_system_reference.m` | H_21_ref of NI card + Nexus; drops the two lines above Nyquist (47.8 and 53.6 kHz); shows the dB-vs-linear mix-up. |
| `part2_sensitivity.m` | Undoes the mix-up, table of the 12 sensitivities, repeatability statistics, 250 Hz vs 1 kHz. |
| `part3_mic_responses.m` | Noise floor, H_pv = H_21/H_21_ref, which mic is which, absolute scaling, f_s (phase = −90°) and Q (magnitude), least-squares cross-check. |
| `part4_model.m` | Model constants from the brief, backplate M_AS / R_AS, the LTspice `.param` line, model against measurement. |

## What was found

- **The Part 2 values on the lab PC are about 277× too large.** `H_21_250`/`H_21_1000` were typed as their dB values (−0.0036) instead of the linear magnitude (0.9996). `part2_sensitivity.m` multiplies back.
- **Sensitivities (1 kHz, mean of 3 calibrators):** Mic 1 = **10.98 mV/Pa**, Mic 2 = **13.03 mV/Pa**, spread about 0.2 %. At 250 Hz both read about 0.35 dB lower. The offset is identical for both mics and all three calibrators, so it is systematic, most likely the narrow summation window in `Calibrate.m` at 250 Hz.
- **Mic 1 = B&K 4134 (pressure field)**, flat with a small rise before resonance: f_s ≈ 20.2 kHz, Q ≈ 0.84. **Mic 2 = B&K 4133 (free field)**, heavily damped (−8.6 dB at 20 kHz): f_s ≈ 22.9 kHz, Q ≈ 0.34. The lab only had the labels "mic 1" / "mic 2", so the types are identified from the response shapes.
- Aligned at 1 kHz, both follow the LTspice model within ±0.5 dB up to 20 kHz (4133 phase within 5°). Above resonance the 4133 departs by up to 1.6 dB / 19°, and its −90° reading and a whole-curve fit differ by 9 % (22.9 vs 21.1 kHz): its air-film damping is not one lumped resistance. The model's fixed level (11.14 mV/Pa) is 0.1 dB below the 4134 and 1.4 dB below the 4133.
- The signal is 60–90 dB above the noise floor (46 dB at 20 Hz). Going from Nav 4 to Nav 64 lowers the noise by 11.6 dB, against 12 dB expected.
- Serial numbers, calibrator certificate values and room conditions were not recorded. The calibrator SPL/frequency values were entered correctly on the lab PC; the conditions were ordinary room conditions.
