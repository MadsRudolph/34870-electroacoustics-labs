# Lab E: loudspeaker response in free field

**Slot:** Tue 20 Oct 08:30, rooms 028/025 (b.354), System D. The quiz covers Lab D and Lab E and is due Mon 26 Oct.

## On the lab PC

1. Copy `Lab E/matlab/` onto the lab PC (USB stick).
2. **Plug the UMIK into USB before you start MATLAB**, or the course routine will not find it. Read the serial number off its label (0329, 0332 or 0335).
3. Open `matlab/labE_run.m` in the editor and set `UmikSN` in section 0.
4. Run section 0b: `test_labE` must print `PASS` (no hardware needed).
5. Run one section at a time with **Ctrl+Enter**. Each run is saved to `data/labE_<tag>.mat` and nothing is ever overwritten. Change the angle in the section and run it again for the next angle.
6. Before you leave, fill in `matlab/labE_dims.m`: the driver diameters, the screen sizes, the driver position on the IEC screen, the microphone distance and height, and how the boxes were placed.
7. Copy `data/` back.

## What gets measured (tags)

| Section | Tags | Settings |
|---|---|---|
| 1a small box | `box_0`, `box_30` | 24/oct, Nav 16, ~17 s each |
| 1b circular screen | `circle_0`, `circle_30` | same |
| 1c IEC screen | `iec_0`, `iec_15`, `iec_30`, `iec_60` | same |
| 2 project system | `system_0`, `system_30`, `system_60` | 48/oct, Nav 64, all three units in **one** run (~4 min) |

For part 2, start on the **woofer** and switch to the **midrange** during the first beeps, then to the **tweeter** during the second. `H(:,1)`, `H(:,2)` and `H(:,3)` in the saved file are then the woofer, midrange and tweeter, in that order. Keeping all three units in one run is what keeps their relative phase valid, because the sound card adds a different random delay to every run. Don't move the microphone between the angles.

## Files

- `matlab/measure_labE.m` is the wrapper around the course routine. It saves `fn`, `specn`, `f`, `spec`, `ch`, `H = p/V` for each unit, the settings and a timestamp.
- `matlab/course/` holds the course files from DTU Learn: `meas_mag_spec2_SoundCard_LabE.m`, `diffrac.m`, `phaseunwrap.m` and the UMIK correction files.
- Note that the routine reads `beeps.wav` while the file is called `Beeps.wav`. That's fine on Windows, but on Linux the name must match.
