# Lab A — Part 4: coil in a magnetic field driving a two-mass suspension, simulation results

Simulated with a KiCad 10 schematic (`Labs/Lab A/KiCad/Part4_Coil_Electromechanical/`) exported through `kicad-cli`
and run in ngspice 47. Scripts: `sim/part4_layout.py` (draws the sheet) and `sim/part4.py` (export, run, plot, numbers,
sign check). Console log: `results/part4_log.txt`. Sweep `.ac dec 200 1 10k`, drive V1 = 1 V AC.
Schematic picture: `figures/sch_Part4_Coil_Electromechanical.png`.

## Modelling choices

- **Mechanical side in the MOBILITY analogy**: velocity = node voltage [m/s], force = branch current [N].
  Mass → capacitor to ground (C = M), compliance → inductor (L = C_m), damper → resistor (R = 1/R_m).
- **Electrical side** as drawn: V1 → Vs1 (0 V current sensor, + upstream, so `I(Vs1)` = coil current i) → R1 = R_c →
  L1 = L_e → E1 (back-EMF, VCVS, gain Bl, senses node `u_c`) → ground. Nodes `e_in, e_a, e_b, e_c`.
- **Transduction** f = Bl·i: a VCCS G1 with gain Bl/R_c senses the voltage across R_c (`e_a` − `e_b` = R_c·i) and
  injects Bl·i (1 A = 1 N) into node `u_c`. Back-EMF v = Bl·u_c is E1 in series with the coil loop. (The lab's
  hint "pay attention to the signs" — see the sign check below.)
- Mechanical network: `u_c` — C1 = M_mc to ground; `u_c`→`u_1` through L2 = C_ms ∥ R2 = 1/R_ms; `u_1` — C2 = M_m1 ∥
  L3 = C_ms2 ∥ R3 = 1/R_ms2 to ground.
- KiCad plot expressions (in the workbook): `V(/u_c)`, `V(/u_1)`, `I(Vs1)`, `1/I(Vs1)` (= Z_E), `1.5*I(Vs1)/V(/u_c)` (= Z_M).

## Element values (physical → SPICE)

| ref | value | SPICE unit | physical |
|---|---|---|---|
| V1 | 1 V AC | V | ideal voltage drive |
| Vs1 | 0 V | V | current sensor, I(Vs1) = i |
| R1 | 0.5 | Ω | R_c |
| L1 | 10 µ | H | L_e |
| E1 | gain 1.5 | V per (m/s) | back-EMF, Bl = B·l = 1 T · 1.5 m |
| G1 | gain 3 | A per V | f = Bl·i = (Bl/R_c)·V(R_c) |
| C1 | 5 m | F ≙ kg | M_mc = 5 g |
| L2 | 10 µ | H ≙ m/N | C_ms = 0.01 mm/N |
| R2 | 1 | Ω ≙ m/(N s) | 1/R_ms, R_ms = 1 Ns/m |
| C2 | 100 m | F ≙ kg | M_m1 = 100 g |
| L3 | 10 m | H ≙ m/N | C_ms2 = 10 mm/N |
| R3 | 10 | Ω | 1/R_ms2, R_ms2 = 0.1 Ns/m |

Derived: electrical damping (Bl)²/R_c = 4.5 Ns/m (much larger than R_ms2 = 0.1 and R_ms = 1);
electrical corner R_c/(2πL_e) = 7.96 kHz.

## Sign check on the back-EMF (mandatory, from `part4.py`)

| E1 gain | max |u_c| | at | |Z_E| there | DC current |
|---|---|---|---|---|
| **+1.5 (as drawn)** | **0.652 m/s per V** | 4.9 Hz | 22.6 Ω | 1.915 A |
| 0 (no back-EMF) | 29.5 m/s per V | 4.9 Hz | 0.50 Ω | 2.000 A |
| −1.5 (flipped) | 0.889 m/s per V | 724 Hz (the 4.9 Hz peak disappears, the 724 Hz one grows — negative damping) | 1.47 Ω | 1.922 A |

With the polarity as drawn the electrical damping (Bl)²/R_c cuts the 4.9 Hz velocity peak by a factor 45 and the
current at resonance drops from 2 A to 44 mA, i.e. the back-EMF opposes the drive — the physically correct sign.
Power check: electrical power into E1 = v·i = Bl·u_c·i equals the mechanical power f·u_c = Bl·i·u_c delivered by G1,
so the transducer is lossless as it must be.

## Hand estimates of the natural frequencies

| mode | formula | f |
|---|---|---|
| both masses riding together on C_ms2 | 1/(2π√((M_mc+M_m1)·C_ms2)) | 4.91 Hz |
| coil bouncing on C_ms against M_m1 (reduced mass 4.76 g) | 1/(2π√(μ·C_ms)), μ = M_mc·M_m1/(M_mc+M_m1) | 729 Hz (712 Hz with M_mc alone) |
| M_m1 resonating on C_ms with the coil held still (anti-resonance seen from the coil) | 1/(2π√(M_m1·C_ms)) | 159 Hz |

## a) Velocities — `figures/part4a_velocities.png`

| | u_c (coil) | u_1 (mass M_m1) |
|---|---|---|
| 1 Hz | 0.188 m/s per V | 0.188 |
| **peak** | **4.90 Hz, 0.652** | **4.90 Hz, 0.652** |
| dip | **158.5 Hz, 4.3e-4** | 436.5 Hz, 0.0158 |
| **peak** | **732.8 Hz, 0.537** | 716 Hz, 0.0272 |
| 10 kHz | 6.0e-3 | 1.8e-6 |

|u_1/u_c| = 1.00 below ~20 Hz, 1.65 at 100 Hz, 0.055 at 700 Hz, 3e-4 at 10 kHz.

- **4.9 Hz — rigid-body mode.** C_ms (0.01 mm/N) is 1000× stiffer than C_ms2, so at low frequency coil and mass move
  as one lump of 105 g on the soft suspension C_ms2: both velocities are equal (phase identical). The peak is broad
  because the electrical damping 4.5 Ns/m dominates (Q ≈ ω₀M/R ≈ 0.7 with the total 4.6 Ns/m); with the back-EMF
  removed (dotted curve) the same mode is only damped by R_ms2 = 0.1 Ns/m and peaks at 29.5 m/s per V.
- Below the first resonance the motion is compliance-controlled (u ∝ jω, +90° phase); between the resonances
  mass-controlled (u ∝ 1/jω, −90°).
- **158.5 Hz — the coil stops.** This is the anti-resonance of the mechanical load: M_m1 on the stiff spring C_ms
  resonates (159 Hz estimate) and presents an almost infinite impedance to the coil, so u_c drops to 4e-4 m/s while
  u_1 keeps moving (|u_1/u_c| = 1.65 at 100 Hz, growing to ~40 right at 158 Hz). It is a vibration-absorber
  (tuned-mass-damper) effect; u_c's phase jumps by +180° there.
- **733 Hz — coil-on-spring mode.** The coil (5 g) bounces on C_ms against the heavy, now almost stationary mass
  (729 Hz reduced-mass estimate). u_c peaks at 0.54 m/s per V; u_1 shows only a small hump (0.027) and then falls at
  −40 dB/decade because the spring C_ms cannot transmit the force to M_m1 at high frequency (mass isolation).
- Above 733 Hz u_c falls as 1/(ωM_mc) (mass control of the coil alone); above 8 kHz L_e also starts to limit the current.
- u_1 has a shallow minimum at 436 Hz where the C_ms spring force and the C_ms2/R_ms2 branch partially cancel — a
  zero of the u_1 transfer function, not a system resonance.

## b) Mechanical input impedance seen by the force — `figures/part4b_mechanical_impedance.png`

Z_M = f/u_c = Bl·I(Vs1)/V(u_c) (numpy from the same run; KiCad expression `1.5*I(Vs1)/V(/u_c)`).

| feature | f | |Z_M| [N s/m] | phase |
|---|---|---|---|
| 1 Hz | — | 15.2 | −90° (compliance C_ms2 dominates) |
| **resonance (minimum)** | **4.90 Hz** | **0.10** (≈ R_ms2 = 0.1 — only the mechanical loss is left) | 0° |
| **anti-resonance (maximum)** | **158.5 Hz** | **6.9e3** | 0° (flip +90 → −90) |
| **resonance (minimum)** | **732.8 Hz** | **1.13** (≈ R_ms = 1 + a bit of R_ms2) | 0° |
| 10 kHz | — | 313 ≈ ω·M_mc = 314 | +90° (coil mass) |

- The impedance seen by the force is the pure mechanical network (the transducer is lossless, so Z_M does *not*
  contain the electrical damping — the back-EMF acts on the electrical side). Minima are where the force meets
  almost no impedance (only the dampers): the two resonances. The maximum is the anti-resonance where M_m1 on
  C_ms takes all the force and the coil cannot move.
- Phase sequence −90° / +90° / −90° / +90°: compliance-like below 4.9 Hz (C_ms2), mass-like between 4.9 and 158 Hz
  (the 105 g lump), compliance-like between 158 and 733 Hz (C_ms, the coil is spring-controlled), mass-like above
  (M_mc).
- Reading the minima: at 4.9 Hz |Z_M| ≈ R_ms2 + (R_ms only marginally, the spring C_ms hardly flexes), at 733 Hz
  |Z_M| ≈ R_ms — the damper values can be read directly off the plot.

## c) Electrical input impedance — `figures/part4c_electrical_impedance.png`

Z_E = V1/I(Vs1) = 1/I(Vs1).

| feature | f | |Z_E| |
|---|---|---|
| 1 Hz | — | 0.522 Ω |
| **peak** | **4.90 Hz** | **22.6 Ω** (motional part 22.1 Ω) |
| broad minimum | ~100–400 Hz | 0.500 Ω = R_c |
| **peak** | **732.8 Hz** | **2.48 Ω** (motional 1.98 Ω) |
| dip | 1.4 kHz | 0.5025 Ω |
| 10 kHz | — | 0.797 Ω ≈ |R_c + jωL_e| = 0.803 |

- Z_E = R_c + jωL_e + (Bl)²/Z_M. The motional term is the **inverse** of the mechanical impedance (Lecture 4
  "impedance conversion": Z_E,M = (Bl)²·Y_M). So the mechanical **resonances** (Z_M minima) appear as **peaks** in
  |Z_E| — (Bl)²/R_ms2 = 22.5 Ω at 4.9 Hz and (Bl)²/1.13 = 2.0 Ω at 733 Hz on top of R_c — and the mechanical
  **anti-resonance** (Z_M maximum, 158 Hz) is where Z_E is closest to R_c ((Bl)²/6.9e3 = 0.3 mΩ): the coil is
  blocked, no back-EMF, the electrical side sees the blocked-coil impedance.
- The Z_E peaks are sharp because on the electrical side the mechanical resonance is loaded only by the mechanical
  dampers (Q ≈ 2π·4.9·0.105/0.1 ≈ 32 for the first mode).
- The phase of Z_E swings +75°/−75° around the peaks (inductive below a resonance, capacitive above — a motional
  impedance looks like a parallel RLC on the electrical side, the classic loudspeaker impedance curve).
- Above ~1.4 kHz the motional term is negligible and Z_E follows R_c + jωL_e; the corner is at 8 kHz, so at 10 kHz
  the phase is +47° and |Z_E| is 0.8 Ω.
- Compared with b): Z_M and Z_E are mirror images on a log scale — every minimum of one is a maximum of the other,
  scaled by (Bl)² = 2.25. That is the whole content of the "mechanical → electrical impedance is an inversion"
  statement from the lecture.

## d) Every resonance / anti-resonance in the three plots

| f | u_c | u_1 | Z_M | Z_E | physical origin |
|---|---|---|---|---|---|
| 4.9 Hz | peak 0.65 | peak 0.65 | min 0.10 (≈R_ms2) | peak 22.6 Ω | both masses (105 g) on the soft suspension C_ms2; rigid-body mode, damped mostly by (Bl)²/R_c |
| 158.5 Hz | **dip 4e-4** (coil stands still) | still moving | **max 6.9e3** | ≈ R_c (0.500 Ω) | M_m1 resonating on the stiff spring C_ms absorbs the force — anti-resonance / tuned-mass-damper effect |
| 436 Hz | — | shallow dip | — | — | zero of the u_1 transfer (spring force vs. suspension branch), not a system mode |
| 733 Hz | peak 0.54 | small hump 0.027 | min 1.13 (≈R_ms) | peak 2.5 Ω | coil (5 g) bouncing on C_ms against the nearly stationary M_m1 (reduced mass 4.76 g → 729 Hz) |
| 8 kHz | roll-off steepens | — | — | inductive rise | electrical corner R_c/(2πL_e); L_e limits the current, no mechanical origin |

Compare with the lab's question "describe the vibration velocity and the forces as a function of the driving
current" (Problem 4.3e in the lecture): f_coil = Bl·i always; the force in the spring C_ms is f − jωM_mc·u_c, which
is ≈ f below 158 Hz (the coil mass is negligible) and → 0 above 733 Hz (the coil mass takes the whole force).

## Open issues / notes for the report

- All peaks are extracted from a 200-points-per-decade sweep, so frequencies are quoted to ±0.5 %.
- The lab asks for "mech. mobility or impedance analogy" — mobility was used; in the impedance analogy the same
  circuit would need a gyrator (H/F sources) instead of E/G, the plots are identical.
- The far-off cosmetic item: KiCad prints the inductor values of horizontal parts rotated over the symbol; the values
  are in the notes block on the sheet.
