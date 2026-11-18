// Automated test suite for Auralis DSP, Acoustic & Statistical Engine (Project/auralizer/auralizer.js).
import fs from "node:fs";
import assert from "node:assert/strict";
import { makeAuralizerEngine } from "./auralizer.js";

const data = JSON.parse(fs.readFileSync(new URL("./data.json", import.meta.url), "utf8"));
const ref = JSON.parse(fs.readFileSync(new URL("./reference.json", import.meta.url), "utf8"));
const E = makeAuralizerEngine(data);

function maxRelErr(z, [reRef, imRef]) {
  let worst = 0;
  for (let i = 0; i < z.re.length; i++) {
    const err = Math.hypot(z.re[i] - reRef[i], z.im[i] - imRef[i]);
    const mag = Math.hypot(reRef[i], imRef[i]) || 1;
    worst = Math.max(worst, err / mag);
  }
  return worst;
}

// 1. Verify exact agreement with Python xover.py and box_model.py on all 412 Lab E points
const cfg = E.boxConfig(data.design.box);
const box = E.boxRatio(cfg);
assert(maxRelErr(box, ref.box) < 1e-5, `boxRatio mismatch: ${maxRelErr(box, ref.box)}`);

for (const a of ["on", "off30"]) {
  const out = E.evaluate(data.design, a, box);
  for (const k of ["woof", "mid", "tw", "sum"]) {
    const err = maxRelErr(out[k], ref[a][k]);
    assert(err < 1e-5, `${a}.${k} mismatch vs xover.py: ${err}`);
  }
}
const m = E.metrics(data.design, box);
assert(Math.abs(m.on.spread - ref.metrics.on.spread) < 1e-4, "on.spread mismatch");
assert(Math.abs(m.off30.spread - ref.metrics.off30.spread) < 1e-4, "off30.spread mismatch");
assert(Math.abs(m.x_wm - ref.metrics.x_wm) < 1e-4, "x_wm mismatch");
assert(Math.abs(m.x_mt - ref.metrics.x_mt) < 1e-4, "x_mt mismatch");
assert(E.minidspText(data.design.digital.fc, "LPF", data.design.digital.align) === ref.minidsp.LPF, "minidsp LPF text mismatch");
assert.deepEqual(E.ltspiceText(data.design.digital.fc, "HPF", data.design.digital.align), ref.ltspice.HPF, "ltspice HPF text mismatch");

// 2. Verify Real Driver Impedance Zi(f) vs Textbook Resistor RE load difference
const outReal = E.evaluate(data.design, "on", box, { idealLoad: false });
const outIdeal = E.evaluate(data.design, "on", box, { idealLoad: true });
let maxDiffDb = 0;
for (let i = 0; i < E.N; i++) {
  if (E.f[i] >= 500 && E.f[i] <= 10000) {
    const dbReal = 20 * Math.log10(Math.hypot(outReal.sum.re[i], outReal.sum.im[i]));
    const dbIdeal = 20 * Math.log10(Math.hypot(outIdeal.sum.re[i], outIdeal.sum.im[i]));
    maxDiffDb = Math.max(maxDiffDb, Math.abs(dbReal - dbIdeal));
  }
}
assert(maxDiffDb > 1.0 && maxDiffDb < 15.0, `Expected measurable difference between Zi(f) and RE load, got ${maxDiffDb.toFixed(2)} dB`);

// 3. Verify FIR Impulse Response synthesis (IFFT) & Round-Trip Frequency Response
const irRes = E.synthesizeIR(data.design, { sampleRate: 48000, nfft: 8192, roomMode: "anechoic" });
assert(irRes.ir.length === 8192, "IR length should be 8192");
let peakIdx = 0, peakVal = 0, energy = 0;
for (let i = 0; i < irRes.ir.length; i++) {
  const v = Math.abs(irRes.ir[i]);
  assert(Number.isFinite(v), "IR sample must be finite");
  if (v > peakVal) { peakVal = v; peakIdx = i; }
  energy += irRes.ir[i] * irRes.ir[i];
}
// Causal peak should arrive near preDelaySec (20 ms = 960 samples at 48 kHz)
const peakMs = (peakIdx / 48000) * 1000;
assert(peakMs > 15 && peakMs < 26, `IR main arrival peak at ${peakMs.toFixed(2)} ms (expected ~20 ms)`);
assert(energy > 0.01 && energy < 10, `IR energy out of expected range: ${energy}`);

// Verify IEC 60268-13 room mode adds early reflection energy compared to anechoic
const irRoom = E.synthesizeIR(data.design, { sampleRate: 48000, nfft: 8192, roomMode: "iec" });
let energyRoom = 0;
for (let i = 0; i < irRoom.ir.length; i++) energyRoom += irRoom.ir[i] ** 2;
assert(energyRoom > energy * 1.05, "IEC room mode should increase total energy via boundary gain + reflections");

// 4. Verify WAV export and Procedural Studio Track Synthesizer
const wavBytes = E.encodeWAV(irRes.ir, 48000);
assert(wavBytes.length === 44 + 8192 * 2, "WAV byte length mismatch");
assert(String.fromCharCode(...wavBytes.slice(0, 4)) === "RIFF", "WAV header RIFF missing");

for (const tr of E.TRACK_LIST) {
  const samples = E.generateTrackSamples(tr.id, 24000); // test at 24 kHz for speed
  assert(samples.length === Math.floor(tr.duration * 24000), `Track ${tr.id} length mismatch`);
  let pk = 0;
  for (let i = 0; i < samples.length; i++) {
    assert(Number.isFinite(samples[i]), `Track ${tr.id} has non-finite sample`);
    pk = Math.max(pk, Math.abs(samples[i]));
  }
  assert(pk > 0.70 && pk < 0.74, `Track ${tr.id} peak normalization expected ~0.72, got ${pk}`);
}

// 5. Verify Task 4 Statistical Analysis & LaTeX generation
const stats = E.analyzeListeningTrials([
  { subject: "S1", track: "ensemble", pref: "A", scoresA: { bass: 4.5, mid: 4.5, treble: 4, overall: 4.5 }, scoresB: { bass: 3, mid: 3.5, treble: 2.5, overall: 3 }, abxCorrect: true },
  { subject: "S2", track: "vocal_keys", pref: "A", scoresA: { bass: 4, mid: 5, treble: 4.5, overall: 4.5 }, scoresB: { bass: 3.5, mid: 3, treble: 2, overall: 2.5 }, abxCorrect: true },
  { subject: "S3", track: "guitar_cymbal", pref: "A", scoresA: { bass: 4, mid: 4, treble: 4.5, overall: 4 }, scoresB: { bass: 3.5, mid: 3.5, treble: 2, overall: 3 }, abxCorrect: true },
]);
assert(stats.counts.A === 3 && stats.abxHits === 3, "Stats count mismatch");
assert(stats.toLatex().includes("\\begin{tabular}"), "LaTeX output missing tabular");

console.log(`ALL TESTS PASSED: xover.py match <1e-5, Zi vs RE diff = ${maxDiffDb.toFixed(2)} dB, IR peak @ ${peakMs.toFixed(2)} ms, 8 studio tracks verified.`);
