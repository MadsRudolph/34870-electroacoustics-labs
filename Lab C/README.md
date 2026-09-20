# Lab C — Microphone calibration (calibrators, pistonphone, electrostatic actuator)

Room 026, building 354. Quiz (Lab B + C together, individual): deadline **Mon 5 Oct 2026**. Brief: `34870_Lab_C_ActuatorCalibration_E2026.pdf` on DTU Learn. Microphones: B&K 4133 (S/N 591628) and B&K 4134 (S/N 1534527).

| Folder | What |
|---|---|
| `matlab/course/` | The course routines `meas_mag_spec2`, `Calibrate`, `createMultitone_w`, unchanged. |
| `matlab/measure_labC.m` | One multitone measurement with the brief's parameters, saved at once as `data/labC_<tag>.mat`; for the system reference it prints `H_21_250` and `H_21_1000`. |
| `matlab/calibrate_labC.m` | One single-frequency calibration (Part 2), corrected with `H_21` and appended to `data/labC_calibration_log.csv`. |
| `matlab/process_labC.m` | Statistics of the sensitivities, `H_pv = H_21/H_21_ref`, noise-floor plot, f_s and Q (slide procedure **and** a least-squares fit), backplate M_AS / R_AS, measurement vs. model figure, and the `.param` line for LTspice. |
| `ltspice/` | `gen_labC_ltspice.py` → `LabC_CondenserMics.asc`: three-domain model of both microphones; you only type the measured `fs` and `Q`, LTspice derives M_AS and R_AS. `--verify` runs it headless and checks it against the closed form. |

## In the lab (order matters)

```matlab
measure_labC('ref', 'system')                                  % Part 1, prints H_21_250 and H_21_1000
calibrate_labC('4133', '42AG #1', 1000, 94.0, H_21_1000)       % Part 2: f and SPL from the device's sticker!
calibrate_labC('4133', 'pistonphone', 250, 124.0, H_21_250)    %   every microphone x every device, 2-3 repeats
measure_labC('noise_4133', 'mic')                              % Part 3b: actuator supply OFF
measure_labC('noise_4133_N64', 'mic', 64)
measure_labC('resp_4133', 'mic')                               % Part 3c: actuator supply ON, everybody quiet
measure_labC('resp_4134', 'mic')
```
