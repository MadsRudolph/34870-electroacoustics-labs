# Lab A – Part 3: dual diaphragm with radiation loading on both sides (results)

Source: `sim/part3.py` → `KiCad/Part3_Coupled_Stiff/`, `KiCad/Part3_Coupled_Soft/` (kicad-cli export, ngspice,
`.ac dec 200 10 10k`). Part 1 decks are re-run by the same script for the overlays.
Figures: `figures/part3a_velocities.png`, `part3a_impedance.png`, `part3b_pressures.png`,
`part3b_farfield_split.png` (copies in the vault `Images/LabA/`).

## Model

Part 1 circuit (mobility analogy) + for **each** diaphragm an acoustic sub-network (impedance analogy,
p ↔ V, U ↔ I) representing the radiation impedance of a baffled piston seen by BOTH faces, coupled to the
velocity node with two voltage-controlled current sources (Lecture 4A, slide 8, mobility form):

- G_a (`G2` inner, `G4` outer): injects **U = S·u** into the acoustic node `p_i` / `p_o`
  (control = velocity node, output from ground into the p node). Gain = S.
- G_m (`G1` inner, `G3` outer): draws the reaction force **f = S·p** out of the velocity node
  (control = p node, output from the u node to ground). Gain = S.
- Net effect on the mechanical side: an admittance S²·Z_A in parallel with the mass (mobility analogy).

Radiation network per diaphragm (Lecture 3 §8b), both sides in series = every impedance × 2:

| | inner diaphragm S_i = 60 cm², a = 43.7 mm | outer diaphragm S_o = 210 cm², a = 81.8 mm |
|---|---|---|
| M_A1 = 8ρ/(3π²a), one side | 7.295 kg/m⁴ | 3.900 kg/m⁴ |
| R_A1 = 0.441ρc/(πa²) | 29 835 Pa·s/m³ | 8 524 |
| R_A2 = ρc/(πa²) | 67 653 Pa·s/m³ | 19 330 |
| C_A1 = 5.94a³/(ρc²) | 3.551e‑9 m⁵/N | 2.325e‑8 |
| **in SPICE, both sides:** L = 2M_A1 | L4 = 14.59 H | L5 = 7.799 H |
| R = 2R_A2 (series, from p node) | R4 = 135.3 kΩ | R6 = 38.66 kΩ |
| R = 2R_A1 (‖ C) | R5 = 59.67 kΩ | R7 = 17.05 kΩ |
| C = C_A1/2 (‖ R_A1) | C3 = 1.775 nF | C4 = 11.62 nF |
| topology | L ‖ [R_A2 + (R_A1 ‖ C_A1)] between p node and ground | same |
| added moving mass 2S²M_A1 | **0.525 g** | **3.44 g** |
| HF radiation resistance 2S²R_A2 (ka ≫ 1) | **4.87 Ns/m** | **17.05 Ns/m** |
| ka = 1 at f = c/(2πa) | **1253 Hz** | **670 Hz** |

Sign check (evidence the coupling is a load, not a generator): with the air load the resonance moves
DOWN (51.3 → 43.7 Hz; hand: 51.2·√(11/(11+0.525+3.44)) = 43.9 Hz ✓), the peak velocity DROPS
(1.389 → 1.314 m/s per N) and the real part of Z_M at 10 kHz rises from 0.74 to 22.8 Ns/m
(= 0.72 + 4.87 + 17.05 = 22.6 ✓). A wrong sign would have raised the peak or made it unstable.

## a) Velocities and impedance, Part 1 → Part 3

| Case | feature | Part 1 | Part 3 (with air) |
|---|---|---|---|
| Stiff | resonance | 51.3 Hz, 1.389 m/s/N | **43.7 Hz, 1.314** |
| Stiff | |Z_M| minimum | 0.720 Ns/m | 0.761 |
| Stiff | Z_M at 10 kHz | 0.74 + j692 | **22.8 + j693** |
| Soft | first resonance | 51.3 Hz, 1.388 | 43.7 Hz, 1.314 |
| Soft | u_vc dip / |Z_M| maximum | 1288 Hz, 334 Ns/m | **1023 Hz, 129 Ns/m** |
| Soft | second resonance (u_vc peak, |Z| min) | 1799 Hz, 0.0415, 24.1 Ns/m | **1718 Hz, 0.0264, 37.9 Ns/m** |
| Soft | u_d maximum | 1738 Hz, 0.0493 | 1549 Hz, 0.0257 |
| Soft | Z_M at 10 kHz | 5.7 + j372 | 10.6 + j372 |
| Soft | u_vc/u_d at 10 kHz | 42 | 43 |

Explanation:
- **Low frequency (ka ≪ 1)** the radiation impedance is almost purely mass-like (jωM_A1 dominates the
  parallel network): the air adds 0.5 g + 3.4 g of co-moving mass to 11 g, so the resonance drops to
  43.7 Hz for both links. The radiation resistance there is tiny (∝ (ka)²), so the peak height is nearly
  unchanged; the drop from 1.389 to 1.314 is mostly the Q change from the extra mass at fixed R.
- **Around ka ≈ 1** (670 Hz outer, 1253 Hz inner) the network turns resistive. For the soft link the
  absorber frequency of the outer diaphragm drops from 1288 to 1023 Hz (its mass grew from 5 to 8.4 g:
  1/(2π√(8.44 g · 3 µm/N)) = 1000 Hz) and, more importantly, its 17 Ns/m of radiation resistance damps
  the absorber: the u_vc dip is 8 dB shallower and the anti-resonance in Z_M falls from 334 to 129 Ns/m.
  The second resonance is likewise lower and about 4 dB lower in amplitude.
- **High frequency (ka ≫ 1)** the load is a pure resistance ρc S² per side. Stiff: 21.9 Ns/m in series
  with the 11 g mass line, invisible in |Z| (692 Ns/m reactive) but it is the whole radiated power. Soft:
  only the inner diaphragm is still moving, so only its 4.87 Ns/m shows up (10.6 = 5.7 + 4.9).
- **Effect of the radiation impedance, in one sentence**: a frequency-dependent load that is extra mass at
  low frequency (lowers all resonances) and extra damping at high frequency (flattens the absorber
  anti-resonance and sets the radiated power); on the outer diaphragm it is ~7× larger than on the inner one.

## b) Sound pressure (figure `part3b_pressures.png`, split in `part3b_farfield_split.png`)

`p_front` in front of one face = V(p_x)/2 (the p node carries the sum of both faces). Far field on axis at
1 m, half space (infinite baffle): p = jωρ(S_i u_vc + S_o u_d)/(2π·1 m), computed from the node voltages.

| Case | quantity | value |
|---|---|---|
| both | p_front inner / outer at the 44 Hz resonance | 15.9 / 29.8 Pa per N |
| Stiff | p_front plateau 100 Hz – 1 kHz inner / outer | ≈ 3 / 5.6 Pa per N (10 / 15 dB) |
| Stiff | p_front at 10 kHz, both | 0.59 Pa per N (falls once ka > 1: velocity ∝ 1/f, R_rad constant) |
| Soft | p_front inner: 2nd peak / 10 kHz | 10.0 Pa per N at 1738 Hz / 1.10 at 10 kHz |
| Soft | p_front outer: 2nd peak / 10 kHz | 10.9 Pa per N at 1567 Hz / 0.03 at 10 kHz |
| both | far-field peak at 44 Hz | 1.85 Pa per N at 1 m |
| Stiff | far field 100 Hz – 10 kHz | flat ≈ 0.35–0.46 Pa per N (−9 … −7 dB) |
| Soft | far field | 0.35 plateau, **+8 dB hump at 1.6 kHz (0.87)**, −18 dB dip at ≈3 kHz (0.12), 0.18 at 10 kHz |

Explanation:
- Near-field pressure per face is Z_rad(f)·S·u. Below ka = 1 the load is mass-like, so p_front ≈ ωM_A1·S·u,
  which with u ∝ 1/f gives the flat plateau; the outer face sits 5 dB above the inner because M_A1·S ∝ a.
  Above ka = 1 the load is the resistance ρc/S, so p_front ≈ ρc·u for either face (same 0.59 Pa/N at 10 kHz
  in the stiff case) and falls ∝ 1/f with the velocity.
- Far field with constant force: in the mass-controlled region ωρ·S·u is flat (ω × 1/ω), which is the
  familiar flat loudspeaker response above resonance. **Stiff**: one 11 g piston, flat to 10 kHz in this
  lumped model (real cones would break up; the model has no cone modes).
- **Soft (the dual-diaphragm principle)**: up to ~1 kHz the outer cone provides 78 % of the volume velocity
  (S_o/(S_i+S_o)); around 1.6 kHz the link resonance boosts the output (+8 dB hump, the outer cone is
  resonating on C_md); above ~2 kHz the outer cone decouples, its velocity falls 12 dB/oct faster and it
  ends up in anti-phase, so around 3 kHz the two partially cancel (dip); from ~4 kHz upward only the inner
  cone radiates: −13 dB relative to the low-frequency plateau (= 20·log(60/270)) but *flat*, extending the
  bandwidth well beyond where a 210 cm² cone of 11 g would have rolled off or broken up. Design intent:
  large area for bass efficiency, small light area for treble; the soft joint is a mechanical crossover.
- Modelling assumptions the lab told us to take: each diaphragm loaded as an independent baffled piston
  (no mutual radiation impedance between the two, no dipole cancellation of the inner cone even though it
  sits in the throat of the outer one), and the total volume velocity is the plain sum U_i + U_o. Both
  overestimate the treble output somewhat, and the lumped radiation network is itself a fit valid
  to ka ≈ a few, i.e. ~2–5 kHz for the outer cone.
