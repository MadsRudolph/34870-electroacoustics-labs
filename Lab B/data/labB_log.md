# Lab B log — Group 10, Tue 22 Sep 2026, 10:00–12:00, b.354 room 028/025

Written up after the lab from memory and from the data (Mads, 22-Sep). The lab PC's
course script `labB.m` was used instead of `measure_labB`, so the files hold only
`h = specn(:,2)./specn(:,1)`; `matlab/import_group_files.m` turns them into the
`labB_<tag>.mat` files that `process_labB` reads. Originals: `data/Lab B master group 10/`.

| Item | Value |
|---|---|
| UMIK serial number | **708-0332** (`UmikSN='708-0332'` in `labB.m`), incidence correction 90° |
| Mock-up diameter (tape) | **not measured** — the brief's nominal 250 mm is used in `process_labB` (the measured 0° rise below 2 kHz matches the BEM for 250 mm within 1 dB) |
| Mock-up length (tape) | not measured (BEM assumes 855 mm) |
| Back end of the mock-up | round (BEM `Round` used) |
| Loudspeaker front → UMIK distance | **2.8 m** for the whole angle series and the reference (the reference file is called `no_mockup_1.8m` on the lab PC: a typo, 0.93 → 2.8 m gives the −9.6 dB that 1/r predicts and the data shows) |
| UMIK height / driver facing the mic | not noted |
| Gap UMIK tip → mock-up face | **about 2–3 cm**, not flush (the data shows the BEM's 3 cm field-point notch at 3.9 kHz) |
| Amplifier volume setting | not noted; **not changed** during the session (reference, angle series and Part 0 all at the same level) |
| Room temperature | not measured (c = 344 m/s assumed) |
| Photo of setup | — |
| Lab PC clock | runs ahead of real time (last file stamped 13:11, the slot ended 12:00); file times below are lab-PC time |

| File (lab PC) | Pipeline file | Lab-PC time | Mock-up angle | Note |
|---|---|---|---|---|
| test.mat | — | 12:31 | ? | trial run, matches no reference, not used |
| mockup_0.mat | labB_ang000.mat | 12:37 | 0° | |
| mockup_30.mat | labB_ang030.mat | 12:42 | 30° | |
| mockup_60.mat | labB_ang060.mat | 12:45 | 60° | |
| mockup_90.mat | labB_ang090.mat | 12:48 | 90° | |
| mockup_45.mat | labB_ang045.mat | 12:53 | 45° | |
| mockup_15.mat | labB_ang015.mat | 12:56 | 15° | |
| mockup_75.mat | labB_ang075.mat | 13:01 | 75° | |
| no_mockup_1.8m.mat | labB_nomockup.mat, labB_dist280cm.mat | 13:04 | — | reference, mic at 2.8 m, taken AFTER the series (no start reference → no drift check) |
| no_mockup_1.4m.mat | labB_dist140cm.mat | 13:09 | — | Part 0, mic moved to 1.4 m |
| no_mockup_0.93.mat | labB_dist93cm.mat | 13:11 | — | Part 0, mic moved to 0.93 m |

Order of events: trial → 0°, 30°, 60°, 90°, 45°, 15°, 75° with the mock-up rotated
around the fixed UMIK → mock-up out, reference at 2.8 m → mic moved to 1.4 m and
0.93 m for the 1/r check (Part 0 done last, not first as the brief suggests, so it did
not disturb the series). Signal-to-noise plots were not saved (no raw spectra in the files).
