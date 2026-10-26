// node test_engine.mjs: the JS engine against xover.py for the design in design.json.
// data.json stores the measurements to 6 significant digits, so agreement is ~5e-6 relative, not 1e-15.
const TOL = 2e-5, TOLDB = 1e-3;
import { readFileSync } from "node:fs";
import { makeEngine } from "./engine.js";

const D = JSON.parse(readFileSync(new URL("./data.json", import.meta.url)));
const R = JSON.parse(readFileSync(new URL("./reference.json", import.meta.url)));
const E = makeEngine(D);
const des = D.design;
let ok = true;
const check = (label, good, msg) => { ok &&= good; console.log(`  ${good ? "OK " : "BAD"} ${label}: ${msg}`); };

const box = E.boxRatio({ MAP: des.box.MAP, fill: des.box.fill ?? 1 });
const worst = (a, ref) => {
  let w = 0;
  for (let i = 0; i < E.N; i++) {
    const r = Math.hypot(ref[0][i], ref[1][i]);
    w = Math.max(w, Math.hypot(a.re[i] - ref[0][i], a.im[i] - ref[1][i]) / r);
  }
  return w;
};
check("box ratio B(f)", worst(box, R.box) < 1e-6, worst(box, R.box).toExponential(1));
for (const ang of ["on", "off30"]) {
  const out = E.evaluate(des, ang, box);
  for (const k of ["woof", "mid", "tw", "sum"]) {
    const w = worst(out[k], R[ang][k]);
    check(`${ang} ${k}`, w < TOL, w.toExponential(1));
  }
}
const za = E.evaluate(des, "on", box).Zamp2;
check("Z amp ch. 2", worst(za, R.Zamp2) < TOL, worst(za, R.Zamp2).toExponential(1));
const s = E.score(des, box);
check("score", Math.abs(s - R.score) < TOLDB, `${s.toFixed(6)} vs ${R.score.toFixed(6)}`);
const m = E.metrics(des, box), rm = R.metrics;
check("metrics", Math.abs(m.on.spread - rm.on.spread) < TOLDB && Math.abs(m.off30.rms - rm.off30.rms) < TOLDB &&
      m.x_wm === rm.x_wm && m.x_mt === rm.x_mt && Math.abs(m.Zamp2_min - rm.Zamp2_min) < TOLDB,
      `spread ${m.on.spread.toFixed(3)}, x ${m.x_wm}/${m.x_mt}, Zmin ${m.Zamp2_min.toFixed(3)}`);
for (const k of ["LPF", "HPF"]) {
  check(`MiniDSP ${k}`, E.minidspText(des.digital.fc, k, des.digital.align) === R.minidsp[k], "text identical");
  check(`LTspice ${k}`, JSON.stringify(E.ltspiceText(des.digital.fc, k, des.digital.align)) === JSON.stringify(R.ltspice[k]), "strings identical");
}
console.log(ok ? "ALL OK" : "MISMATCH");
process.exit(ok ? 0 : 1);
