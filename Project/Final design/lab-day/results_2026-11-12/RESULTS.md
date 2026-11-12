# Lab day 12-Nov: results (anechoic chamber, Group 10, System D)

Data: `../data/2026-11-12/` (labgui, unchanged from the lab PC; the group's own notes are in
`NOTES.md` there). Figures and numbers: `../analysis/results_1112.m` -> this folder.

## In short
- **Placement is identical to Lab E.** Run P matches the bare Lab E units to 0.2-0.7 dB rms,
  with all three units at the same level (+2.2 dB).
- **The midrange dip at 300-450 Hz was the MiniDSP:** Out 2's LR4 high-pass was applied
  **twice**. The change in the mid/tweeter channel against 10-Nov fits exactly two extra MiniDSP
  high-pass sections (0.6 dB rms misfit; one or three sections misfit by 3.9 / 3.7 dB). The second
  LR4 turns the woofer/mid phase at the crossover from +2 deg to -141 deg, so the two partly
  cancel (up to -11 dB at 400 Hz).
- **Rp 3.3 -> 8.2 ohm works as predicted:** +2.9 dB in the tweeter band (S_3 vs S_4, same chain),
  following the prediction from the 10-Nov data within about 0.3 dB up to 10 kHz.
- **With the extra high-pass removed** (computed from S_3's own phase-coherent channels), the system
  with Rp 8.2 is **5.5 dB spread / 1.23 dB rms** from 150 Hz to 15 kHz. 10-Nov was 7.1 / 1.60, and
  the prediction for Rp 8.2 was 5.3 / 1.20. With Rp 3.3 (S_4) it is 7.4 / 1.72.
- The fixed MiniDSP was not measured today: **the first job next time is one `S` run** to confirm.

## Runs

| Run | Time | Settings | Verdict |
|---|---|---|---|
| P | 13:19 | MiniDSP bypassed, 2.44 m | **valid placement check**; mid and tweeter were NOT behind the board (they match the bare Lab E units, not the through-board curves) |
| S | 13:37 | vent 160 field, 2.44 m | **not usable:** amplifier channels swapped (the "woofer only" state plays the high-passed signal, "mid+tw" the low-passed one) |
| S_2 | 13:51 | vent unplugged, connections reseated | **not usable:** same channel swap |
| S_3 | 13:56 | correct channels, **Rp 8.2**, 2.44 m | woofer = 10-Nov within 0.2 dB (150-1000 Hz); mid/tw with the double high-pass |
| S_4 | 14:03 | **Rp 3.3** back, mic 2.26 m | same double high-pass; reference for the Rp comparison |
| S_5 | 14:11 | Out 1 changed (woofer +4.5 dB, not logged) | balance BAD (+5.6 dB); a gain change cannot fix a phase problem |

The group's notes describe S/S_2 as "S1/S2 columns swapped"; it is the amplifier channels
(S_3's note says so too). They also call P "units via board"; the data say the units were driven
directly. Below about 120 Hz S_3 sits above 10-Nov because the vent was open from S_2 on. The
chamber is not valid there anyway.

## Figures
- `fig_system.png`: 10-Nov, S_3 as measured, and S_3 with the extra high-pass removed.
- `fig_double_filter.png`: today's mid/tw divided by 10-Nov's, against 1, 2 and 3 extra MiniDSP
  sections.
- `fig_phase.png`: woofer vs mid/tw phase (same run): 10-Nov about 0 deg, S_3 -141 deg, corrected
  about +10 deg.
- `fig_rp.png`: Rp 8.2 vs 3.3, measured against predicted.
- `fig_placement.png`: P against the bare Lab E units.

## What to do next time
1. **MiniDSP Out 2:** Xover -> Advanced must hold exactly the two biquads from
   `data/dsp/MiniDSP_midtw_out2.txt`, with no other high-pass active (basic Xover settings, a
   leftover filter, the text pasted twice). **Scope check with a 325 Hz sine: Out 2 = -6 dB.**
   **-12 dB means the filter is doubled.** Out 1 should read **-11.8 dB** (-6 dB filter + the -5.8 dB gain).
2. **Out 1 = -5.8 dB** again (S_5 changed it by about +4.5 dB).
3. **Keep Rp = 8.2 ohm.**
4. Measure **`S`** first (expect balance OK, spread about 5.5 dB), then `S4`, `S5`, `F`, `A`,
   then the Zi station (`Z1`-`Z4`, `N1`, `N2`).
5. Placement P does not need repeating (identical to Lab E). If it is repeated with the MiniDSP
   bypassed, keep the tweeter behind the board, or the volume low: a bare tweeter on a
   full-range signal is at risk.
