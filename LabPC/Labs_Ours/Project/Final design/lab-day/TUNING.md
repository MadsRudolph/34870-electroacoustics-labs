# Tuning plan: from flat to "sounds good" (System D, Group 10)

Based on the 10-Nov measurements (`results_2026-11-10/LabDay_Results.pdf`). Update this file
when something is tried, with the date and what the measurement or the listening showed.

## 1. Settings to use now

| Where | Setting | Why |
|---|---|---|
| MiniDSP Out 1 (woofer) | **-5.8 dB** (design -4.5; it sat at 0 dB at the start on 10-Nov) | woofer vs mid/tw balanced to -0.1 dB in this lab's amplifier chain |
| MiniDSP Out 2 (mid + tweeter) | 0 dB | reference |
| MiniDSP crossover | LR4 325 Hz from `../data/dsp/MiniDSP_*.txt`, no invert, no delay, PEQ/Comp/FIR bypassed | woofer handover already in phase (flip notch -32 dB at 315 Hz) |
| Passive board, tweeter L-pad | Rs 4.7 ohm, **Rp 3.3 -> 8.2 ohm** (try on 12-Nov) | tweeter was 2.7 dB low and mid 1.5 dB high. From the measured R2 units: spread 150 Hz-15 kHz 7.2 -> 5.3 dB, rms 1.64 -> 1.20 dB, amplifier load >= 4.1 ohm. Script: `analysis/pad_predict.m` |
| Rest of the board | L_mid 0.82 mH, C_mid 6.8 uF, C_tw 5.6 uF, L_tw 0.22 mH | unchanged |
| Vent | plugged in the chamber; **one vent open at 160 mm** for near field, listening, demo | 160 mm is the design (f_B 24.6 Hz) |

`design.json` still says Rp 3.3. Change it only once the 8.2 ohm board is measured and kept. The
GUI's expected curves are the design, which assumes the tweeter at its intended level. With 8.2 ohm
the measurement should move onto them, so S5 and S3 should turn green.

Left alone on purpose: 1-3 kHz about 1.5 dB high (needs a different midrange filter), and the
8.3 kHz dip (in the tweeter's own Lab E response; the crossover cannot remove it).

## 2. What "flat" means: the measurement target (anechoic, vents plugged)

1. On axis within **+-2 dB from 150 Hz to 15 kHz** (1/6 octave). No broad steps or tilts: a
   3 dB shelf over two octaves is heard much more than a narrow 6 dB dip.
2. **30 deg follows 0 deg**: the same shape, rolling off smoothly above about 5 kHz, with no
   step at the 3.8 kHz mid/tweeter crossover (run A; not measured yet).
3. Crossovers in phase: both flip notches deeper than 10 dB near 330 Hz and 4 kHz (run F).
4. Woofer vs mid+tw within +-1 dB (run S; the GUI's balance lamp).
5. Bass (near field, vent open at 160 mm): f_3 about 33 Hz, no peak above the passband.

## 3. From flat to "sounds good": in the IEC room

What listeners prefer in blind tests (Toole/Olive), in order: a flat, smooth on-axis response;
off-axis sound that looks like on-axis, only quieter; units that add in phase at the crossovers;
deep bass without boom; low distortion. A speaker that is flat in the chamber and whose
directivity rises smoothly gives a **gentle downward tilt in the room (about -1 dB/octave)**,
and that is what most people like. So start flat; the room adds the tilt.

Knobs allowed by the course rules (the MiniDSP's PEQ/Comp/FIR stay bypassed):

| Knob | Changes | Typical step |
|---|---|---|
| Out 1 gain | bass and lower mids (< ~325 Hz) against the rest | +-1-2 dB ("fuller" / "leaner") |
| L-pad Rs/Rp (Appendix 1 values) | tweeter level above ~4 kHz | +-1-3 dB ("bright" / "dull") |
| MiniDSP crossover frequency | woofer/mid handover | 300-400 Hz; the woofer beams above ~500 Hz |
| Passive mid/tweeter values | mid/tweeter handover and overlap | lower = smoother directivity, limited by the tweeter's 1.45 kHz resonance |
| Vent length | bass extension vs boom | 160 mm design |

Procedure:
1. Check the balance in the IEC room first (its own amplifier): start from Out 1 -5.8 dB and adjust.
2. Listen with 4-5 familiar tracks and a short questionnaire (balance, brightness, bass, clarity,
   imaging; 1-5).
3. Change **one** knob by 1-2 dB; listen again, blind if possible (one person switches).
4. Measure whatever you keep, so the report shows what "good" means as a curve.

## Log

| Date | Change | Result |
|---|---|---|
| 10-Nov | Out 1 0 -> -5.8 dB | balance -0.1 dB; spread 7.1 dB (tweeter 2.7 dB low) |
| 12-Nov | Rp 3.3 -> 8.2 ohm (planned) | |
