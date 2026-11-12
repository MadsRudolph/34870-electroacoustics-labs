# 12-Nov anechoic runs: notes

Raw files from the lab PC (labgui), copied unchanged from the USB stick.
`labgui_log.txt` timestamps run about 1 h behind the file times.

| Run | Vent | Mic | Note |
|---|---|---|---|
| P | 160 | 2.44 m | placement, units via board |
| S | 160 | 2.44 m | S1/S2 columns look swapped (S1 = high-passed mid+tw, S2 = woofer): do not use |
| S_2 | 200 | 2.44 m | same swap: do not use |
| S_3 | 200 | 2.44 m | woofer = 10-Nov within 0.3 dB |
| S_4 | 200 | 2.26 m | same as S_3 |
| S_5 | 200 | 2.26 m | woofer +4.5 dB vs S_3/S_4 (Out 1 gain changed, not logged) -> "bal BAD" |

## Midrange dip at 300-450 Hz

- S3 = complex S1+S2 within 0.1 dB, so the dip is woofer/mid cancellation.
- Woofer/mid phase at 300-400 Hz: 140-176 deg (10-Nov: 0 +- 5 deg).
- Mid vs 10-Nov: an extra LR4 high-pass at ~325 Hz (-7.7 dB / -176 deg at 300 Hz, -18 dB at 200 Hz).
- Cause: MiniDSP Output 2 (mid+tw) crossover was wrong. Fixed in the lab on 12-Nov after these runs;
  no S run after the fix is in this folder.
