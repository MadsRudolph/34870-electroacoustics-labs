# Lab A — Part 2: car silencer (acoustic ladder), simulation results

Simulated with KiCad 10 schematics exported through `kicad-cli` and run in ngspice 47.
Scripts: `sim/part2_layout.py` (draws the three sheets) and `sim/part2.py` (export, run, plot, numbers).
Full console log: `results/part2_log.txt`.

KiCad projects (`Labs/Lab A/KiCad/`):

| project | source | outlet | used for |
|---|---|---|---|
| `Part2a_Silencer_PressureSource` | V1 = 1 Pa AC (pressure source) | ideal open end, p_out = 0 | a) |
| `Part2b_Silencer_VolumeVelocitySource` | I1 = 1 m³/s AC (volume-velocity source), 100 MΩ leak R0 | ideal open end | b), c) |
| `Part2d_Silencer_Radiation` | I1 = 1 m³/s AC | radiation network (unflanged tube end) | d), e) |

Sweep `.ac dec 200 10 1000` on all three sheets. Every narrow pipe carries a 0 V sense source `Vs1, Vs3, Vs5, Vs7`
(+ terminal upstream) so the pipe volume velocities are `I(Vs1)…I(Vs7)` in KiCad and in batch ngspice. Nodes are
labelled `p_in, p2, p4, p6, p_out`.

## Modelling choices

- **Impedance analogy** on the acoustic side: pressure = node voltage, volume velocity = branch current.
- **Narrow tubes 1, 3, 5, 7** (radius a = 2 mm, S = 1.2566e-5 m²): series inductor `L = M_A = ρ l / S` in series with
  the given loss `R = R_A = 25e3 Pa·s/m³`. Lengths are the effective lengths from Table 2.
- **Chambers 2, 4, 6**: pure shunt compliance `C = C_A = V/(ρ c²)`, V = π r² l, one terminal on the reference
  (ground) — the "always ground closed-volume compliances" rule. Their own air mass is neglected (they are wide).
- **Outlet a/b/c**: ideal open end, p_out = 0 → L7 returns straight to ground.
- **Outlet d/e**: radiation network for an unflanged tube end ("piston in a long tube", Lecture 3 §8b):
  `Z_rad = jωM_A1 ∥ [R_A2 + (R_A1 ∥ C_A1)]`. Because the Table 2 lengths are *effective* lengths and therefore already
  contain the end-correction mass (0.6133·a = 1.23 mm) of the open end, pipe 7 was shortened to
  40 − 1.23 = **38.77 mm** in the radiation sheet so the end mass is not counted twice. (The alternative —
  keeping 40 mm and dropping M_A1 — changes nothing visible: the radiation load is ≥ 30× smaller than the pipe
  impedance everywhere in band, see d.)
- Air: ρ = 1.18 kg/m³, c = 344 m/s.

## Element values (physical → SPICE)

| element | value | unit | how |
|---|---|---|---|
| M_A1 (L1) | 2348 | kg/m⁴ | ρ l/S, l = 25 mm |
| M_A3 (L3) | 7512 | kg/m⁴ | l = 80 mm |
| M_A5 (L5) | 9390 | kg/m⁴ | l = 100 mm |
| M_A7 (L7) | 3756 (a–c) / 3641 (d–e, 38.77 mm) | kg/m⁴ | l = 40 mm |
| R_A1, R_A3, R_A5, R_A7 | 25 000 | Pa·s/m³ | given |
| C_A2 (C2) | 1.125e-10 | m⁵/N | V = 15.71 cm³ |
| C_A4 (C4) | 7.199e-10 | m⁵/N | V = 100.5 cm³ |
| C_A6 (C6) | 3.037e-10 | m⁵/N | V = 42.41 cm³ |
| M_A1,rad (L9) | 115.2 | kg/m⁴ | 0.6133 ρ/(π a) |
| C_A1,rad (C9) | 3.11e-13 | m⁵/N | 0.55 π² a³/(ρ c²) |
| R_A1,rad (R8) | 1.630e7 | Pa·s/m³ | 0.5045 ρc/(π a²) |
| R_A2,rad (R9) | 3.230e7 | Pa·s/m³ | ρc/(π a²) |

Hand estimates of the natural frequencies (f = 1/(2π√(MC))):

| pair | f |
|---|---|
| M_A1–C_A2 | 310 Hz |
| M_A3–C_A2 | 173 Hz |
| M_A3–C_A4 | 68 Hz |
| M_A5–C_A4 | 61 Hz |
| M_A5–C_A6 | 94 Hz |
| M_A7–C_A6 | 149 Hz |
| C_A2 with M_A1 ∥ M_A3 | 355 Hz |
| C_A4 with M_A3 ∥ M_A5 | 92 Hz |
| C_A6 with M_A5 ∥ M_A7 | 176 Hz |
| all four masses in series (23 006) with all three compliances in parallel (1.136e-9) | 31 Hz |

The two-element pairs are only a rough guide: the ladder is a 3-degree-of-freedom system and its modes mix the
neighbouring elements. The "chamber with the two tubes on either side in parallel" estimates hit the simulated
volume-velocity-source peaks (176 Hz) and pressure-source peak (355 Hz) exactly.

## a) Pressure source — `figures/part2a_pressure_source_Uout.png`

|U_out/p_in| (dB re 1 m³/(s·Pa)), from `I(Vs7)` with V1 = 1 Pa:

| feature | frequency | level |
|---|---|---|
| 10 Hz | — | −123.0 dB |
| dip | 42.2 Hz | −132.0 dB |
| **peak** | **76.7 Hz** | **−101.0 dB** |
| dip | 142.9 Hz | −143.9 dB |
| **peak** | **179.9 Hz** | **−112.3 dB** |
| dip | 309.0 Hz | −170.3 dB |
| **peak** | **354.8 Hz** | **−149.6 dB** |
| 1 kHz | — | −253.9 dB |

Interpretation:
- The output is `U_out = p_in / Z_in · (U_out/U_in)`. With a pressure source the low-frequency level is set by the
  **input impedance of the whole ladder**. Below ~1 Hz that would be the four series losses, ΣR_A = 1e5 Pa·s/m³
  (−100 dB), but already at 10 Hz the series air masses dominate: ω·ΣM_A = 2π·10·23 006 = 1.45e6 ≫ 1e5, hence
  |Z_in| ≈ 1.5e6 and −123 dB (`figures/part2_input_impedance.png`). The masses, not the losses, set the LF floor.
- The three peaks (76.7, 179.9, 354.8 Hz) are the **minima of Z_in** (series resonances): with the inlet held at a
  fixed pressure, the network's natural frequencies are those of the ladder with a *short-circuited* (p = 0) inlet.
  The three dips (42, 143, 309 Hz) are where U_out passes through zero between two poles — near the maxima of Z_in
  (parallel resonances, 47, 176, 190 Hz) and the M_A1–C_A2 pair (310 Hz).
- Above the last resonance the response falls at roughly −60 dB/decade per chamber section (a ladder of three
  L-C low-pass sections gives −18 dB/octave per section): −150 dB at 355 Hz → −254 dB at 1 kHz.
- The losses R_A only round off the peaks: at 100 Hz ωM_A3 = 4.7e6 ≫ 2.5e4, so Q ≈ 100–200 and the peaks are very sharp.

## b) Volume-velocity source — `figures/part2b_volume_velocity_source_Uout.png`

|U_out/U_in| (dB), from `I(Vs7)` with I1 = 1 m³/s:

| feature | frequency | level |
|---|---|---|
| 10 Hz | — | +0.44 dB (→ 0 dB as f → 0) |
| **peak** | **47.1 Hz** | **+38.6 dB** |
| dip | 112.2 Hz | −5.2 dB |
| **peak** | **175.6 Hz** | **+40.9 dB** |
| dip | 183.7 Hz | +20.1 dB |
| **peak** | **190.8 Hz** | **+41.1 dB** |
| 1 kHz | — | −111.5 dB |

Transmission loss TL = −20 log|U_out/U_in|: 20 Hz −1.9 dB · 50 Hz −18.2 dB · 100 Hz +4.7 dB · 150 Hz −0.2 dB ·
200 Hz −5.5 dB · 300 Hz +40.6 dB · 500 Hz +73.5 dB · 700 Hz +92.2 dB · 1 kHz +111.5 dB.

Interpretation and **differences to a)** (overlay: `figures/part2ab_source_comparison.png`):
- With an ideal volume-velocity source the flow is forced into the inlet regardless of the pressure it takes. At
  low frequency the chambers cannot store flow (1/(ωC_A) huge), so everything that goes in comes out:
  **0 dB transfer**, no dependence on the series masses or losses.
- The transfer U_out/U_in is a property of the network alone; the source only decides which natural frequencies
  are excited. A volume-velocity source is an *open circuit* at the inlet, so the peaks sit at the
  **open-inlet natural frequencies = maxima of Z_in** (47.3 and 175.8/190 Hz), exactly where the pressure-source
  response has its dips. Conversely the pressure-source peaks (Z_in minima) do not appear at all with the U source.
- The peaks reach about +40 dB (corrected 20-Sep-2026: the first run had a 100 MΩ leak resistor loading the source and a 200 points/decade sweep, which gave +26 dB and a shoulder instead of a third peak): at those frequencies the ladder resonates and the silencer *amplifies* the flow. A real
  engine exhaust is somewhere between the two ideal sources (finite source impedance), which is why silencer
  design has to know the source impedance.
- Above 200 Hz the chambers shunt the flow to ground and the mass of the following pipe blocks it; the roll-off is
  the same −18 dB/oct per section as in a), reaching 111 dB of transmission loss at 1 kHz.
- Only two clear peaks instead of three: the third open-inlet mode sits at 190 Hz, right next to 176 Hz, and shows
  up as the shoulder of the second peak. In a) the corresponding modes were 180 and 355 Hz.

## c) Volume velocity in each pipe (U source) — `figures/part2c_pipe_volume_velocities.png`

| pipe | 1 kHz level | peaks |
|---|---|---|
| 1 | 0 dB everywhere | (it *is* the source current) |
| 3 | −30.2 dB | 47 Hz +8.7 dB · 176 Hz +19.9 dB · 191 Hz +22.0 dB; dip at 51 Hz (−22 dB) |
| 5 | −78.7 dB | 47 Hz +24.9 dB · 176 Hz +18.5 dB · 188 Hz +14.2 dB; dip at 150 Hz (−39 dB) |
| 7 | −111.4 dB | 47 Hz +38.6 dB · 176 Hz +40.9 dB · 191 Hz +41.1 dB |

- `I(Vs1)` = U_in by definition (the pipe-1 current is what the source injects), so it is a flat 0 dB line.
- Each expansion chamber acts as an acoustic low-pass: chamber 2 shunts part of U_1 so U_3 < U_1, chamber 4 takes
  another bite, chamber 6 the last. At 1 kHz the cumulative attenuation is 30 → 79 → 112 dB after 1, 2 and 3 chambers,
  i.e. each chamber section contributes ~30–40 dB there.
- The dips in U_3 (51 Hz) and U_5 (150 Hz) are anti-resonances where the downstream part of the ladder presents a
  very high impedance, so almost no flow enters that pipe and the chamber before it takes it all. Pipe 7 has no
  dip because nothing follows it (ideal open end).
- The resonance peaks appear in every pipe but grow towards the outlet: energy stored in the resonating chambers is
  released into the pipe after them.

## d) Near-field pressure at the opening — `figures/part2d_near_field_pressure.png`

p_open = `V(/p_out)` in `Part2d_Silencer_Radiation`, U_in = 1 m³/s:

| f | |p_open| |
|---|---|
| 10 Hz | 77.6 dB re 1 Pa (7.6 kPa per m³/s) |
| 100 Hz | 92.5 dB |
| 1 kHz | 5.7 dB |

- The radiation impedance of the 2 mm tube end is essentially a **pure mass** in this band: ka = 0.037 at 1 kHz,
  so Z_rad ≈ jωM_A1 with M_A1 = 115 kg/m⁴; at 1 kHz |Z_rad| = 7.24e5 Pa·s/m³ with Re = 1.08e4 (1.5 %). The dashed
  curve ωM_A1|U_out| lies on top of the simulated |p_open|. The resistive part R_A2 = 3.2e7 is only reached far above
  the band (ka ≈ 1 → 27 kHz).
- Consequently p_open ≈ jωM_A1·U_out: the pressure curve is the U_out curve of b) tilted by +6 dB/octave. Its shape
  (peaks at 47 and 176 Hz, then a steep fall) is that of U_out.
- Inserting the radiation load changes U_out by < 0.01 dB everywhere: |Z_rad| ≤ 7e5 while the pipe-7 impedance
  is ωM_A7 ≥ 2.3e5 at 10 Hz and 2.3e7 at 1 kHz, plus the 2.5e4 loss. The silencer does not "see" the outside air;
  the outlet is a good approximation of an open end.

## e) Pressure at 10 m — `figures/part2e_pressure_10m.png`

Free-space (4π) point source: p(r) = jωρ U_out e^{−jkr}/(4πr), |p| = ρ f |U_out|/(2r), computed in numpy from
`I(Vs7)` of the radiation sheet, plotted as SPL re 20 µPa for U_in = 1 m³/s (scale linearly: a realistic
U_in = 1e-3 m³/s is 60 dB lower).

| f | SPL with silencer | unsilenced (U_out = U_in) |
|---|---|---|
| 20 Hz | 97.3 dB | 95.4 dB |
| 50 Hz | 121.6 dB | 103.4 dB |
| 100 Hz | 104.7 dB | 109.4 dB |
| 200 Hz | 120.9 dB | 115.4 dB |
| 500 Hz | 49.9 dB | 123.4 dB |
| 1 kHz | 17.9 dB | 129.4 dB |

- The far-field pressure of a monopole rises 6 dB/octave for constant U (the dashed reference), so the radiated
  SPL is the U_out transfer of b) plus this tilt. The silencer helps only above ~230 Hz (≈ 75 dB gain at 500 Hz,
  110 dB at 1 kHz) and *hurts* by up to 18 dB at its two resonances (47 and 176 Hz) when driven by an ideal
  volume-velocity source.
- Validity at higher frequencies:
  - Lumped elements require l < λ/10. Pipe 5 (100 mm) meets this only below **344 Hz**, pipe 3 and chamber 4
    (80 mm) below 430 Hz, chamber 6 below 573 Hz, chamber 2 below 688 Hz, pipe 7 below 860 Hz, pipe 1 below 1.4 kHz.
    Above roughly 350–450 Hz the pipes and chambers must be treated as transmission lines (ABCD/two-port model
    of Lecture 3 §4); the lumped −18 dB/oct-per-section roll-off then becomes a sequence of pass/stop bands
    (the first half-wave resonance of the 100 mm pipe is c/(2l) = 1.7 kHz, of the 80 mm chamber 2.15 kHz).
    The grey band in the figure marks this region — the 111 dB transmission loss at 1 kHz is not to be trusted.
  - The plane-wave / lumped assumption across the chamber radius holds (ka = 1 at 2.7 kHz for the 20 mm chamber),
    so no transverse modes in band.
  - The point-source assumption for the 2 mm exit is excellent (ka ≪ 1 up to tens of kHz), and r = 10 m ≫ λ
    (kr = 1.8 at 10 Hz, 183 at 1 kHz) so we are in the far field except at the very lowest frequencies.
  - Free-space radiation ignores the car body and the road: a tailpipe near the ground and under a car sees a
    half-space (+6 dB) and reflections/diffraction; the losses R_A = 25e3 are a crude constant, whereas viscous
    losses in a 2 mm pipe actually grow with √f; the chamber walls are assumed rigid; hot exhaust gas has a
    different ρ and c than the 20 °C air assumed here.
