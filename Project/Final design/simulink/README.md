# System D in Simulink / Simscape

MATLAB R2026a demonstrations of the two course LTspice circuits. Open MATLAB in this folder and run `open_models`.

- **`System_D_frequency_sweep.slx` (start here): press Run to get magnitude and phase versus frequency.** The input sweeps 40 Hz to 22 kHz in 1 s, followed by 0.45 s for the response to decay. A figure opens automatically with woofer, midrange, tweeter and combined responses. The optional Scope still shows the time waveform. Edit a component and Run again to update the frequency plot. Simulation can take longer than the 1.45 s signal duration.
- `Woofer_Vented_L160_simscape.slx`: electrical, mechanical and acoustical impedance-analogy loops, with the exact rounded values in `Woofer_Vented_L160.asc`. Run applies a 1 V, 25 Hz sinusoid for 0.2 s. Open **Inspect flows and current** for coil current, cone flow, vent flow and box-compliance flow. The acoustic currents use electrical units in Simscape because this is an electrical analogy.
- `System_D_simulink.slx`: 96 kHz digital LR4 filters at 325 Hz, woofer gain, physical passive crossover, measured-response FIR filters and the on-axis acoustic sum. Run applies a 1 V, 1 kHz sinusoid. Open **Pressure at microphone**. Double-click **Passive crossover - open me** to see the components and speaker impedance circuits.
- `System_D_passive_simscape.slx`: the same passive network on its own, used for linearisation and verification.

The full-system file embeds its coefficients in its model workspace. It can be opened and simulated without the Python preparation script or a base-workspace setup. Double-click individual blocks to inspect their values. The two loudspeaker models are educational alternatives; the LTspice circuits remain the course submission versions.

## What carries over, and what is approximate

The woofer uses exactly the same lumped circuit and total-output convention as the compact LTspice version: total far-field pressure is derived from the flow through Cab. As in that circuit, the leak branch is excluded from this output; the full physical net flow would instead be UD-UP. The numerical check compares complex responses (magnitude **and phase**), not just the plotted magnitudes.

In the full system the inductors, capacitors and L-pad are physical Simscape elements. Speaker impedance is represented by the group's fitted Lab D passive equivalents:

`Re + sLe + (sLeddy || Reddy) + (Rmot || sLmot || 1/sCmot)`

The motional parallel circuit has `Rmot=Bl^2/Rms`, `Lmot=Bl^2*Cms`, `Cmot=Mmd/Bl^2`. This is a fitted approximation to the Zi tables, not the exact measured-table load used by LTspice.

Each Lab E transfer function becomes a 32768-tap real FIR at 96 kHz, interpolated in magnitude and unwrapped phase. The common distance correction agrees with the LTspice files. All drivers receive the **same additional 170.667 ms delay** to place the finite impulse response causally in time. This delay changes absolute timing but preserves relative driver phase. It is removed when comparing frequency responses. Below the measured band the response is ramped to zero, and above it it is tapered to zero by 24 kHz; neither extension is a validated speaker prediction. The comparison band is 150 Hz–15 kHz. The full-system demo currently uses the on-axis measurements.

## Rebuild and verify

From this folder:

```sh
python3 prepare_system_data.py
matlab -batch build_woofer_simscape
matlab -batch build_system_simulink
matlab -batch build_frequency_sweep
```

Requires MATLAB, Simulink, Simscape, Signal Processing Toolbox, plus Python/NumPy. Builders regenerate the `.slx` models, so save hand-edited experiments under a different name.

The woofer builder compares the circuit's linearised impedance and flows to independent equations over 5–500 Hz, runs a time-domain simulation and writes plots under `figures/`.

The system builder verifies the passive circuit against independent ladder equations, checks its observable poles, compares the full predicted response against the measured-table design exported from `design/xover.py`, and runs a 1 kHz time-domain simulation. Its plot separates the impedance-fit error from the FIR-conversion error. Console output records the measured errors; `.mat` files preserve validation arrays. Changing `design/design.json` requires rerunning the preparation script and builder.

`open_models.m` opens the woofer and sweep demonstrations. Double-click the passive crossover subsystem to inspect its circuit.

The sweep uses the actual logged input and all four outputs: `H(f)=FFT(p)/FFT(Vin)`. `plot_frequency_sweep.m` is the model's Stop callback and must remain beside the `.slx`; its folder is added to the MATLAB path when the model opens. The full response tail is retained and the common artificial FIR delay is removed from the displayed phase. Very weak branch phases are hidden. The saved `frequency_sweep_validation.mat` contains the complex response, while `figures/system_frequency_sweep.png` contains the plot. If you stop early, the callback does not present a partial sweep as a completed response.

The time-domain sweep includes the sample-and-hold driving the continuous passive network, so small differences from the ideal continuous-input frequency calculation are expected at high frequencies.

## Verified results (8 November 2026)

- Woofer complex impedance and flow agreement with the compact LTspice circuit equations: numerical precision (magnitude differences below 2e-14 dB); fB 24.6 Hz and f3 33.1 Hz on the simulation grid.
- Passive crossover complex relative errors against ladder equations: below 5e-12. Observable/excitable poles have negative real parts.
- Full on-axis response versus the measured-table design, 150 Hz–15 kHz: median absolute magnitude difference 0.057 dB, maximum 0.766 dB. FIR conversion alone: median 0.003 dB, maximum 0.062 dB.
- Full-model time simulation at 1 kHz: 1.177345 Pa steady amplitude versus 1.170370 Pa predicted, difference 0.0516 dB. The time simulation includes sampled excitation of the continuous physical circuit.

### Run-button sweep verification

The actual time-domain sweep agrees with the exact zero-order-hold discrete equivalent of the physical circuit to a median 0.0001 dB and maximum 0.0007 dB (150 Hz–15 kHz). The verification uses the matrix exponential to obtain the sampled network, then evaluates the digital filters and FIRs at the same frequencies as the FFT estimate. Run `verify_frequency_sweep` after the default model's sweep to repeat this check.

Against the ideal continuous-input AC calculation, the same time-domain sweep differs by a median 0.125 dB and up to 2.680 dB over this band. This is mainly the sampling/hold behavior, not FFT estimation error. The earlier 0.766 dB comparison describes the ideal continuous-input frequency calculation with fitted loads, not this time-domain run.
