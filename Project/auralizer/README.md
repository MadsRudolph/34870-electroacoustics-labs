# Auralis — Virtual Listening Room & Crossover Auralizer (System D)

Self-contained WebAudio real-time convolution listening room, transient/phase analyzer, and IEC 60268-13 blind listening test suite for **DTU 34870 Electroacoustics — Group 10 (System D: Scan-Speak 26W/8534G00 + DALI Spektor 2)**.

Open [`index.html`](./index.html) directly in any browser — no server or installation required.

## Rebuild & Verify

```bash
python3 build_auralizer.py --test
```

- Reads the measured data from `../data/csv/` and the current design from `../design/design.json` (read-only; never touches `../app/` or other folders).
- Verifies [`auralizer.js`](./auralizer.js) against `../design/xover.py` and `../ltspice/task1/box_model.py` via [`test_auralizer.mjs`](./test_auralizer.mjs) (`< 1e-5` relative error across all 412 Lab E frequencies).
- Bundles everything into a single self-contained [`index.html`](./index.html).

## Key Capabilities

1. **Full-Band (10 Hz – 20 kHz) Complex-Phase FIR Convolution Engine**
   - Above 125 Hz, uses the distance-compensated ($d = -1.15\text{ m}$) Lab E anechoic complex transfer functions ($\text{TF}_{\text{woof}}, \text{TF}_{\text{mid}}, \text{TF}_{\text{tw}}$ at $0^\circ$ and $30^\circ$) and tapering above $18\text{ kHz}$ to suppress the UMIK ultrasonic glitch.
   - Below 125 Hz (where the b.354 anechoic chamber cuts off), smoothly splices the validated **Task 1 impedance-analogy enclosure circuit model** ($p_{1\text{m}}(f)$ for closed box, 1 vent at length $L$, or 2 vents) so you can directly audition bass extension ($f_3$) vs. port resonance ripple ($f_B$).
   - Synthesizes an 8192-tap causal FIR impulse response ($f_s = 48\text{ kHz}, \Delta f = 5.86\text{ Hz}, t_0 = 20.0\text{ ms}$) loaded into dual-buffered WebAudio `ConvolverNode`s with 45 ms equal-power crossfading for click-free real-time A/B/X and parameter switching.

2. **Acoustic Physics & Lecture 9 Checks**
   - **Real Driver Impedance $Z_i(f)$ vs. Textbook Resistor $R_E$ Load**: Toggle live between the Lab D measured driver impedances and nominal pure resistances ($R_{E,\text{mid}} = 4.7\,\Omega, R_{E,\text{tw}} = 3.5\,\Omega$) to hear and inspect the **4.72 dB** passive filter shift (Project Guide p. 3 / Lecture 9 Slide 26 check).
   - **Real Crossover Phase vs. Linear Phase**: Toggle zero-phase mode to audition whether all-pass crossover phase rotation and driver time offsets are audible on transients and tone bursts.
   - **Per-Driver Solo, Mute & Polarity Flip ($\pm$)**: Isolate the woofer, midrange, or tweeter, or flip any unit's polarity to hear the acoustic cancellation notch at $f_{x,\text{WM}}$ ($325\text{ Hz}$) or $f_{x,\text{MT}}$ ($3.76\text{ kHz}$).

3. **Interactive Room Stage & Dispersion Explorer**
   - Drag the listener horizontally from **$0^\circ$ on-axis to $30^\circ$ off-axis** and vertically **ear height $\Delta y \in [-30, +30]\text{ cm}$** (computing exact geometric path-length phase shifts from the Lab E System D coordinates in `labE_dims.m`).
   - Switch between **b.354 Anechoic Free-Field** and **IEC 60268-13 Listening Room** (adds floor/wall boundary bass loading + early reflections weighted by the $30^\circ$ off-axis speaker response) plus **Binaural Headphone Crossfeed**.

4. **8 Built-In Studio Reference & Diagnostic Signals + Custom Audio Upload**
   - Procedural studio loops tailored to System D (*Full Studio Reference*, *Sub & Port Groove*, *Baritone Formant & Warm Keys*, *Acoustic Guitar & Brushed Cymbals*, *IEC 60268-13 Pink Noise*, *Dual Crossover Band-Noise*, *Synchronized Log Sine Sweep*, *Linkwitz Tone Bursts*), plus upload for any `.wav`/`.mp3`/`.flac`/`.ogg` file.

5. **Task 4 IEC 60268-13 Blind Listening Test & ABX Suite**
   - **Double-Blind ABX Challenge** with exact binomial $p$-value calculation.
   - **Multi-Subject Blind Questionnaire** (80 dB(A) loudness-matched, randomized Candidate #1 / #2 order, 1–5 scales for Bass, Midrange, Treble, Overall, and Preference) with live 95% confidence-interval plotting and one-click export of `results_task4.tex` for `Project/report/Project_report.tex`.
   - **Live Sync with Crossover Studio** (`⇄ Sync Studio` button) via shared browser storage.
