# Lab A – Part 1: dual-diaphragm loudspeaker, mechanical system (results)

Source: `sim/part1.py` → KiCad projects `KiCad/Part1_DualDiaphragm_Stiff/` and `.../Soft/`
(exported with kicad-cli, run in ngspice, `.ac dec 200 10 10k`). Figures in `figures/part1*.png`
(copies in `Obsidian/Courses/34870 Electroacoustics/Images/LabA/`).

## Model and element mapping (mechanical MOBILITY analogy: u ↔ V, f ↔ I)

Sketch of Fig. 4: force F on M_mvc; M_mvc hangs on the spider C_msp‖R_msp to ground; M_mvc is linked to
M_md through C_md‖R_md; M_md hangs on the surround C_msr‖R_msr to ground. Two velocity nodes: `u_vc`, `u_d`.

| Physical element | Value | SPICE element | Value | Connection |
|---|---|---|---|---|
| Force F | 1 N | I1 (AC current source) | 1 A | ground → `u_vc` (current injected into the node) |
| M_mvc | 6 g | C1 | 6 mF | `u_vc` – ground |
| C_msp | 1.3 mm/N | L1 | 1.3 mH | `u_vc` – ground |
| R_msp | 0.5 Ns/m | R1 = 1/R_msp | 2 Ω | `u_vc` – ground |
| C_md (link) | 1e‑10 / 3e‑6 m/N | L2 | 1e‑10 H / 3 µH | `u_vc` – `u_d` |
| R_md (link) | 5000 / 5 Ns/m | R2 = 1/R_md | 0.2 mΩ / 0.2 Ω | `u_vc` – `u_d` |
| M_md | 5 g | C2 | 5 mF | `u_d` – ground |
| C_msr | 2.7 mm/N | L3 | 2.7 mH | `u_d` – ground |
| R_msr | 0.22 Ns/m | R3 = 1/R_msr | 4.545 Ω | `u_d` – ground |

Readouts: velocities are the node voltages `V(u_vc)`, `V(u_d)` (m/s per N). Mechanical input impedance
seen by the force: Z_M = F/u_vc = **1/V(u_vc)** (1 A source). In KiCad add the trace `1/V(/u_vc)`
(user-defined signal, already in the `.wbk`); in LTspice the same expression via *Add traces*.

## Hand values

- Parallel suspensions: 1/C_tot = 1/1.3 + 1/2.7 (N/mm) → **C_tot = 0.8775 mm/N**; M_tot = 11 g;
  R_tot = R_msp + R_msr = 0.72 Ns/m.
- Stiff-link resonance f0 = 1/(2π√(M_tot C_tot)) = **51.2 Hz**, Q = √(M_tot/C_tot)/R_tot = 4.9.
- Soft link: outer diaphragm on the link spring alone f = 1/(2π√(M_md C_md)) = **1300 Hz** (absorber /
  anti-resonance frequency); two masses bouncing against each other through C_md with the suspensions
  negligible: f = 1/(2π√(C_md · M_md M_mvc/(M_md+M_mvc))) = **1760 Hz** (second resonance, undamped estimate).

## a) Velocity response (figure `part1a_velocities.png`, ratio in `part1_velocity_ratio.png`)

| Case | feature | frequency | value |
|---|---|---|---|
| Stiff | single resonance, u_vc = u_d | 51.3 Hz | 1.389 m/s per N (= 1/R_tot) |
| Stiff | u_d/u_vc over the whole band | – | 1.000 (0.998 at 10 kHz) |
| Soft | first resonance (both masses in phase) | 51.3 Hz | 1.388 (u_vc), 1.389 (u_d) |
| Soft | u_vc dip (anti-resonance, absorber) | 1288 Hz | 0.0030 m/s per N |
| Soft | u_d maximum around the link resonance | 1738 Hz | 0.0493 |
| Soft | second resonance (masses in anti-phase) | 1799 Hz | u_vc 0.0415 |
| Soft | u_vc/u_d at 10 kHz | – | 42 (outer diaphragm 32 dB below the coil) |

Interpretation:
- **Stiff link**: C_md = 1e‑10 m/N is a rigid rod for every frequency of interest (its own resonance with
  the 5 g mass would be at 225 kHz), so both masses move as one 11 g body on the two suspensions in
  parallel. One resonance at 51 Hz, below it the compliance controls (u ∝ f, +90°), above it the mass
  controls (u ∝ 1/f, −90°, −6 dB/oct). Identical curves for u_vc and u_d.
- **Soft link**: below ~300 Hz the link is still stiff compared with the masses' inertia, so the low
  resonance is unchanged at 51 Hz with the same peak. Around 1.3 kHz the outer diaphragm on its soft
  spring becomes a **tuned absorber**: it resonates against the coil, the reaction force through C_md
  cancels the drive, and u_vc dips by ~30 dB (1288 Hz) while u_d is still large. Just above (1.7–1.8 kHz)
  the two masses swing in anti-phase (second resonance, phase of u_d flips through −180°). Above that the
  soft link cannot transmit force any more (u ∝ 1/ω² through a compliance): u_d rolls off 12 dB/oct
  faster than u_vc, and the coil ends up driving only its own 6 g. This is the dual-diaphragm trick: the
  large cone works up to ~1.5 kHz, then decouples, and the light inner cone alone carries the top octaves
  without the big cone's mass and break-up.

## b) Mechanical input impedance Z_M = F/u_vc (figure `part1b_impedance.png`)

| Case | feature | frequency | |Z_M| |
|---|---|---|---|
| both | compliance asymptote at 10 Hz | 10 Hz | 0.72 − j17.4 Ns/m (≈ 1/(ωC_tot) = 18.1) |
| both | resonance (minimum) | 51.3 Hz | 0.720 Ns/m = R_tot, phase 0° |
| Stiff | mass asymptote at 10 kHz | 10 kHz | 0.74 + j692 (= ωM_tot, 11 g) |
| Soft | anti-resonance (maximum) | 1288 Hz | 334 Ns/m |
| Soft | second resonance (minimum) | 1799 Hz | 24.1 Ns/m |
| Soft | mass asymptote at 10 kHz | 10 kHz | 5.7 + j372 (= ωM_mvc, only the 6 g coil) |

Interpretation: the impedance is the mirror image of u_vc. Below resonance the suspension dominates
(|Z| ∝ 1/f, −90°: compliance line), at resonance the reactances cancel and the floor is the pure
damping R_tot = 0.72 Ns/m (phase 0), above resonance the mass dominates (|Z| ∝ f, +90°: mass line).
Stiff: one 11 g mass line all the way. Soft: the mass line follows 11 g up to ~1 kHz, then the absorber
produces a **maximum** (anti-resonance, 334 Ns/m: the outer diaphragm is pumping force back into the
coil), then a **minimum** at 1.8 kHz (anti-phase resonance), and finally the line continues at only 6 g
(the outer diaphragm has fallen off). The real part at 10 kHz (5.7 Ns/m) is the power still dissipated
in R_md by the residual relative motion.
