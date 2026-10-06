# Lab D: getting the analysis to run

The measurements from 6-Oct are already in `data/` under tags that the scripts recognise. To get going:

1. `git pull`
2. In `matlab/labD_dims.m`, fill in `d.cone_diam` (the woofer cone diameter we wrote down, in **metres**). Without it, `analyse_labD` skips S_D, M_MS, Bl and C_MS. The rest of the file is already filled in.
3. In MATLAB, `cd` to `Lab D/matlab` and run `r = analyse_labD;`. It covers the free air, the closed box, V_AS, the vents, the near field and the room modes in one go. The plots for the report have to be made separately.

## What was fixed in the data (and why)

- **Tags:** in the lab we reused `vent_L1`, `nf_cone_L1` and so on for every tube length. `import_labD.m` renamed every run based on the note saved in the file:
  - `vent_L160`, `vent_L200`, `vent_L240`
  - `nf_cone_L160/L200/L240`
  - `nf_vent_L160/L200/L240`
- **R:** the measurement was given R_E (3.4 / 4.6 / 5.7) as `'R'` instead of the series resistor, so the saved Z was wrong. Z has been recomputed with **R = 32.9 Ω**.
- **V_amp = 2 × AI0:** AI0 sat at about +9.4 V DC and only read half the amplifier voltage. We think the amplifier has a bridged output. With the factor 2, |Z| goes to R_E at low frequencies, as it should. This applies to both Z and the near-field H.

## Files

- `data/labD_<tag>.mat` is the run used by the analysis. `data/labD_<tag>_rN.mat` are all the repeats, in the order they were measured.
  - Used runs: `tweeter` = r5, `midrange` = r3, `woofer_free` = r2 (the ones with the least noise and no clipping), `nf_cone_L240` = r2.
- Each file contains:
  - `fn` (frequency) and `Z` (or `H` for the near field)
  - `specn` (raw spectra)
  - `note`
  - `src` (original file name)
  - `dc_AI0` and `clip_AI0` (fraction of samples on +10 V)
- The original lab-PC files (865 MB, including time signals) are **not** in git. Mads has them, in `raw data/` on his PC. `import_labD.m` rebuilds `data/` from them.
- The room temperature was not recorded, so the analysis assumes 20 °C.
