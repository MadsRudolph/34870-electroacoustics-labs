// Auralis DSP, Acoustic & Statistical Engine for System D (DTU 34870 Electroacoustics).
// Extends the exact Task 1 (box_model.py) and Task 2 (xover.py) physics with:
//   1. Full-band (10 Hz - 24 kHz) complex transfer function synthesis (splicing the validated Task 1
//      enclosure model below the 125 Hz anechoic chamber cutoff, and tapering the >18.4 kHz UMIK glitch).
//   2. Real Driver Impedance Zi(f) vs. Textbook Resistor RE load comparison (Lecture 9 Slide 26 check).
//   3. Continuous horizontal off-axis interpolation (0 deg -> 30 deg) + vertical listener height
//      geometric path-length phase modelling from Lab E's System D coordinates (labE_dims.m).
//   4. Arbitrary-length radix-2 FFT / IFFT, minimum-phase / linear-phase / true-phase FIR impulse
//      response synthesis, step response, and group delay tau_g(f).
//   5. ITU/A-weighted pink-noise loudness matching (for IEC 60268-13 blind A/B tests).
//   6. Task 4 statistical analysis (mean, SD, 95% CI, exact binomial p-value, LaTeX table generator).

export function makeAuralizerEngine(D) {
  const f = Float64Array.from(D.f), N = f.length, TWO_PI = 2 * Math.PI;
  const B = D.box;
  const cx = (re, im) => ({ re: Float64Array.from(re), im: Float64Array.from(im) });
  const TF = {}, ZI = {};
  for (const a of ["on", "off30"]) {
    TF[a] = {};
    for (const u of ["woof", "mid", "tw"]) TF[a][u] = cx(...D.tf[a][u]);
  }
  for (const u of ["mid", "tw"]) ZI[u] = cx(...D.zi[u]);

  // Nominal DC / minimum resistances from Lab D (for textbook RE comparison mode)
  const RE_NOM = { mid: 4.7, tw: 3.5 };
  const ZI_RE = {
    mid: { re: new Float64Array(N).fill(RE_NOM.mid), im: new Float64Array(N) },
    tw: { re: new Float64Array(N).fill(RE_NOM.tw), im: new Float64Array(N) },
  };

  // System D physical driver coordinates in metres (Lab E labE_dims.m & Crossover Studio):
  // Woofer centre at (0, 0.29), Midrange at (-0.12, 0.58), Tweeter at (-0.12, 0.697).
  // Reference Lab E microphone position: on midrange axis (z = 2.44 m, y = 0.58 m).
  const GEOM = {
    woof: { x: 0.0, y: 0.29, z: 0.0 },
    mid: { x: -0.12, y: 0.58, z: 0.0 },
    tw: { x: -0.12, y: 0.697, z: 0.0 },
    refMic: { x: -0.12, y: 0.58, z: 2.44 },
  };

  // ---------------------------------------------------------------- complex helpers
  const C = {
    make: n => ({ re: new Float64Array(n), im: new Float64Array(n) }),
    abs: (z, i) => Math.hypot(z.re[i], z.im[i]),
  };
  const mul = (a, b) => [a[0] * b[0] - a[1] * b[1], a[0] * b[1] + a[1] * b[0]];
  const div = (a, b) => {
    const d = b[0] * b[0] + b[1] * b[1] || 1e-30;
    return [(a[0] * b[0] + a[1] * b[1]) / d, (a[1] * b[0] - a[0] * b[1]) / d];
  };
  const add = (a, b) => [a[0] + b[0], a[1] + b[1]];
  const sub = (a, b) => [a[0] - b[0], a[1] - b[1]];
  const inv = a => div([1, 0], a);
  const get = (z, i) => [z.re[i], z.im[i]];
  const db = (z, i) => 20 * Math.log10(Math.hypot(z.re[i], z.im[i]) + 1e-18);

  // ---------------------------------------------------------------- Task 1 box model (box_model.py)
  const RHO = B.rho, C0 = B.c;
  function zPiston(w, a, baffled) {
    const S = Math.PI * a * a;
    const MA1 = 8 * RHO / (3 * Math.PI ** 2 * a) * (baffled ? 1 : 0.6133 / 0.8488);
    const RA1 = 0.441 * RHO * C0 / S, RA2 = RHO * C0 / S, CA1 = 5.94 * a ** 3 / (RHO * C0 * C0);
    const y1 = inv([0, w * MA1]);
    const r1c = inv(add([1 / RA1, 0], [0, w * CA1]));
    return inv(add(y1, inv(add([RA2, 0], r1c))));
  }
  function boxDict({ fill = 1, RAB = 0, QL = 1e9, MAP = null, RAP = 0 } = {}) {
    const CAB = B.VB * fill / (RHO * C0 * C0);
    return { CAB, RAB, RAL: QL / (TWO_PI * 20 * CAB), MAP, RAP, ap: B.AP };
  }
  function ventBox(MAP, fill = 1) {
    const wb = 1 / Math.sqrt(MAP * B.VB * fill / (RHO * C0 * C0));
    return boxDict({ fill, RAB: B.RAB, QL: B.QL, MAP, RAP: wb * MAP / B.QP });
  }
  function boxSystem(freqs, bx) {
    const d = B.drv, n = freqs.length;
    const out = { ZE: C.make(n), UD: C.make(n), UP: C.make(n), p1m: C.make(n) };
    for (let i = 0; i < n; i++) {
      const w = TWO_PI * Math.max(1e-3, freqs[i]);
      let Zfront, Zbox;
      if (!bx) { Zfront = zPiston(w, B.AD, false); Zbox = Zfront; }
      else {
        Zfront = zPiston(w, B.AD, true);
        let Yb = add(inv(add([bx.RAB, 0], inv([0, w * bx.CAB]))), [1 / bx.RAL, 0]);
        if (bx.MAP) Yb = add(Yb, inv([bx.RAP, w * bx.MAP]));
        Zbox = inv(Yb);
      }
      const ZM = add([d.Rms, w * d.Mmd - 1 / (w * d.Cms)], mul([B.SD * B.SD, 0], add(Zfront, Zbox)));
      const ZE = add([B.RE, w * d.Le], div([d.Bl * d.Bl, 0], ZM));
      const cur = inv(ZE);
      const UD = div(mul([B.SD * d.Bl, 0], cur), ZM);
      const UP = bx && bx.MAP ? div(mul(Zbox, UD), [bx.RAP, w * bx.MAP]) : [0, 0];
      const p = mul([0, w * RHO / TWO_PI], sub(UD, UP));
      for (const [k, v] of [["ZE", ZE], ["UD", UD], ["UP", UP], ["p1m", p]]) {
        out[k].re[i] = v[0]; out[k].im[i] = v[1];
      }
    }
    return out;
  }

  const MAPfit = B.MAP.slice().sort((a, b) => a[0] - b[0]);
  function mapAt(L) {
    let k = 0;
    while (k < MAPfit.length - 2 && L > MAPfit[k + 1][0]) k++;
    const [L0, m0] = MAPfit[k], [L1, m1] = MAPfit[k + 1];
    return Math.max(5, m0 + (m1 - m0) * (L - L0) / (L1 - L0));
  }
  const tubeMass = (L, a) => RHO * (L + 1.46 * a) / (Math.PI * a * a);
  function boxConfig(box) {
    const fill = box.fill ?? 1;
    if (box.mode === "plugged") return { MAP: null, fill, label: "vents plugged (closed box)" };
    if (box.mode === "one") return { MAP: mapAt(box.L ?? 0.16), fill, label: `one vent, L = ${((box.L ?? 0.16) * 1e3).toFixed(0)} mm` };
    if (box.mode === "two") {
      const L1 = box.L ?? 0.16, L2 = box.L2 ?? 0.16, a2 = box.a2 ?? 0.05;
      const m1 = mapAt(L1), cal = m1 / tubeMass(L1, B.AP), m2 = cal * tubeMass(L2, a2);
      return { MAP: m1 * m2 / (m1 + m2), fill, label: `two vents (L ${(L1 * 1e3).toFixed(0)} + ${(L2 * 1e3).toFixed(0)} mm)` };
    }
    if (box.MAP !== undefined) return { MAP: box.MAP, fill, label: box.label || (box.MAP ? `vented (MAP=${box.MAP.toFixed(1)})` : "vents plugged") };
    return { MAP: null, fill, label: "vents plugged" };
  }
  const closedRef = boxSystem(f, boxDict({ RAB: B.RAB })).p1m;
  function boxRatio(cfg) {
    const r = C.make(N);
    if (!cfg.MAP && (cfg.fill ?? 1) === 1) { r.re.fill(1); return r; }
    const p = boxSystem(f, cfg.MAP ? ventBox(cfg.MAP, cfg.fill) : boxDict({ RAB: B.RAB, fill: cfg.fill })).p1m;
    for (let i = 0; i < N; i++) {
      const q = div(get(p, i), get(closedRef, i));
      r.re[i] = q[0]; r.im[i] = q[1];
    }
    return r;
  }
  function f3Ripple(freqs, p, lo = 150, hi = 300) {
    const L = Array.from(freqs, (_, i) => db(p, i));
    const ks = L.filter((_, i) => freqs[i] >= lo && freqs[i] <= hi);
    const ref = ks.reduce((a, b) => a + b, 0) / ks.length;
    let last = -1, rip = -Infinity;
    for (let i = 0; i < freqs.length; i++) {
      if (freqs[i] < lo) { if (L[i] - ref < -3) last = i; rip = Math.max(rip, L[i] - ref); }
    }
    return { f3: last >= 0 ? freqs[last + 1] : freqs[0], ripple: rip, ref };
  }

  // ---------------------------------------------------------------- Digital crossover (MiniDSP 96 kHz)
  const FS = 96e3;
  function bq(f0, Q, kind) {
    const w0 = TWO_PI * f0 / FS, al = Math.sin(w0) / (2 * Q), a0 = 1 + al, c = Math.cos(w0);
    const b0 = kind === "LPF" ? (1 - c) / 2 / a0 : (1 + c) / 2 / a0;
    const b1 = kind === "LPF" ? (1 - c) / a0 : -(1 + c) / a0;
    return [b0, b1, b0, -2 * c / a0, (1 - al) / a0];
  }
  function sections(f0, kind, align) {
    const Qs = {
      BW2: [Math.SQRT1_2],
      LR4: [Math.SQRT1_2, Math.SQRT1_2],
      BW4: [1 / (2 * Math.cos(Math.PI / 8)), 1 / (2 * Math.cos(3 * Math.PI / 8))],
    }[align] || [Math.SQRT1_2, Math.SQRT1_2];
    return Qs.map(Q => bq(f0, Q, kind));
  }
  function hDigitalAt(freqs, f0, kind, align) {
    const n = freqs.length, H = C.make(n);
    H.re.fill(1);
    const secs = sections(f0, kind, align);
    for (let i = 0; i < n; i++) {
      const t = -TWO_PI * freqs[i] / FS, z1 = [Math.cos(t), Math.sin(t)], z2 = mul(z1, z1);
      let h = [1, 0];
      for (const [b0, b1, b2, a1, a2] of secs) {
        const num = add(add([b0, 0], mul([b1, 0], z1)), mul([b2, 0], z2));
        const den = add(add([1, 0], mul([a1, 0], z1)), mul([a2, 0], z2));
        h = mul(h, div(num, den));
      }
      H.re[i] = h[0]; H.im[i] = h[1];
    }
    return H;
  }
  const hDigital = (f0, kind, align) => hDigitalAt(f, f0, kind, align);

  // ---------------------------------------------------------------- Passive crossover (ABCD ladder)
  const TOPOLOGIES = {
    LP1: [["series", "L", "L1"]],
    LP2: [["series", "L", "L1"], ["shunt", "C", "C1"]],
    HP2: [["series", "C", "C1"], ["shunt", "L", "L1"]],
    HP3: [["series", "C", "C1"], ["shunt", "L", "L1"], ["series", "C", "C2"]],
  };
  function passiveParts(b) {
    const parts = TOPOLOGIES[b.topo].map(([pos, kind, n]) => [pos, kind, b.vals[n]]);
    const pad = b.pad || {};
    if (pad.Rs) parts.push(["series", "R", pad.Rs]);
    if (pad.Rp) parts.push(["shunt", "R", pad.Rp]);
    return parts;
  }
  function ladder(parts, Zl, Rdcr = 0, freqs = f) {
    const n = freqs.length, T = C.make(n), Zin = C.make(n);
    for (let i = 0; i < n; i++) {
      const w = TWO_PI * Math.max(1e-3, freqs[i]);
      let A = [1, 0], Bm = [0, 0], Cm = [0, 0], Dm = [1, 0];
      for (const [pos, kind, v] of parts) {
        if (!v) continue;
        const Z = kind === "L" ? [Rdcr * v * 1e3, w * v] : kind === "C" ? [0, -1 / (w * v)] : [v, 0];
        if (pos === "series") { Bm = add(mul(A, Z), Bm); Dm = add(mul(Cm, Z), Dm); }
        else { const Y = inv(Z); A = add(A, mul(Bm, Y)); Cm = add(Cm, mul(Dm, Y)); }
      }
      const zl = get(Zl, i), num = add(mul(A, zl), Bm);
      const t = div(zl, num), zi = div(num, add(mul(Cm, zl), Dm));
      T.re[i] = t[0]; T.im[i] = t[1]; Zin.re[i] = zi[0]; Zin.im[i] = zi[1];
    }
    return { T, Zin };
  }

  // ---------------------------------------------------------------- System Evaluation on Lab E Grid
  function evaluate(des, angle = "on", box = null, opts = {}) {
    const cfg = boxConfig(des.box);
    box = box || boxRatio(cfg);
    const dg = des.digital;
    const HL = hDigital(dg.fc, "LPF", dg.align), HH = hDigital(dg.fc, "HPF", dg.align);
    const gw = 10 ** (dg.g_woof_dB / 20);
    const zMap = opts.idealLoad ? ZI_RE : ZI;
    const m = ladder(passiveParts(des.mid), zMap.mid, des.Rdcr || 0);
    const t = ladder(passiveParts(des.tw), zMap.tw, des.Rdcr || 0);
    // Optional textbook comparison (always computed alongside if requested)
    const mIdeal = opts.idealLoad ? m : ladder(passiveParts(des.mid), ZI_RE.mid, des.Rdcr || 0);
    const tIdeal = opts.idealLoad ? t : ladder(passiveParts(des.tw), ZI_RE.tw, des.Rdcr || 0);

    // Support continuous angle blend (0 = on-axis, 1 = 30 deg off-axis) or string "on" / "off30"
    const blend = typeof angle === "number" ? Math.max(0, Math.min(1, angle / 30)) : (angle === "off30" ? 1 : 0);
    const dy = opts.listenerDy || 0; // vertical ear offset in metres relative to midrange height (0.58 m)

    const P = des.pol;
    const active = opts.active || { woof: true, mid: true, tw: true };
    const out = { woof: C.make(N), mid: C.make(N), tw: C.make(N), sum: C.make(N), Zamp2: C.make(N) };

    for (let i = 0; i < N; i++) {
      const fx = f[i];
      const tfUnit = u => {
        if (blend <= 0) return get(TF.on[u], i);
        if (blend >= 1) return get(TF.off30[u], i);
        // Magnitude + distance-compensated phase interpolation so blending 0° -> 30° never cancels
        const cOn = get(TF.on[u], i), cOff = get(TF.off30[u], i);
        const mOn = Math.hypot(cOn[0], cOn[1]), mOff = Math.hypot(cOff[0], cOff[1]);
        const mag = mOn * (1 - blend) + mOff * blend;
        const pOn = Math.atan2(cOn[1], cOn[0]), pOff = Math.atan2(cOff[1], cOff[0]);
        let dp = pOff - pOn;
        while (dp > Math.PI) dp -= TWO_PI;
        while (dp < -Math.PI) dp += TWO_PI;
        const ph = pOn + blend * dp;
        return [mag * Math.cos(ph), mag * Math.sin(ph)];
      };

      // Vertical listener offset geometric phase shift relative to Lab E reference mic
      const vPhase = u => {
        if (!dy) return [1, 0];
        const g = GEOM[u], m0 = GEOM.refMic;
        const r0 = Math.hypot(m0.x - g.x, m0.y - g.y, m0.z - g.z);
        const r1 = Math.hypot(m0.x - g.x, (m0.y + dy) - g.y, m0.z - g.z);
        const dPhi = -TWO_PI * fx * (r1 - r0) / 345.0;
        return [Math.cos(dPhi), Math.sin(dPhi)];
      };

      const wRaw = mul(mul(mul([P.woof * gw, 0], get(HL, i)), tfUnit("woof")), get(box, i));
      const mdRaw = mul(mul(mul([P.mid, 0], get(HH, i)), get(m.T, i)), tfUnit("mid"));
      const twRaw = mul(mul(mul([P.tw, 0], get(HH, i)), get(t.T, i)), tfUnit("tw"));

      const w = mul(wRaw, vPhase("woof"));
      const md = mul(mdRaw, vPhase("mid"));
      const tw = mul(twRaw, vPhase("tw"));

      const s = [
        (active.woof ? w[0] : 0) + (active.mid ? md[0] : 0) + (active.tw ? tw[0] : 0),
        (active.woof ? w[1] : 0) + (active.mid ? md[1] : 0) + (active.tw ? tw[1] : 0),
      ];
      const za = inv(add(inv(get(m.Zin, i)), inv(get(t.Zin, i))));
      for (const [k, v] of [["woof", w], ["mid", md], ["tw", tw], ["sum", s], ["Zamp2", za]]) {
        out[k].re[i] = v[0]; out[k].im[i] = v[1];
      }
    }
    return Object.assign(out, { HL, HH, Tm: m.T, Tt: t.T, TmIdeal: mIdeal.T, TtIdeal: tIdeal.T });
  }

  // ---------------------------------------------------------------- Smoothing & Metrics (identical to xover.py)
  const lf = Array.from(f, x => Math.log2(x));
  const win = lf.map(x => {
    let a = 0; while (Math.abs(lf[a] - x) > 0.5 / 6) a++;
    let b = a; while (b + 1 < N && Math.abs(lf[b + 1] - x) <= 0.5 / 6) b++;
    return [a, b];
  });
  function smooth(y) {
    const cs = new Float64Array(N + 1);
    for (let i = 0; i < N; i++) cs[i + 1] = cs[i] + y[i];
    return Float64Array.from(win, ([a, b]) => (cs[b + 1] - cs[a]) / (b - a + 1));
  }
  const dbArr = z => Float64Array.from(f, (_, i) => db(z, i));
  const idx = (lo, hi) => { const k = []; for (let i = 0; i < N; i++) if (f[i] >= lo && f[i] <= hi) k.push(i); return k; };
  const median = v => { const s = Array.from(v).sort((a, b) => a - b), n = s.length; return n % 2 ? s[(n - 1) / 2] : (s[n / 2 - 1] + s[n / 2]) / 2; };
  const K = idx(150, 15000), K300 = idx(300, 15000);
  const iFs = f.reduce((b, x, i) => Math.abs(x - D.twFs) < Math.abs(f[b] - D.twFs) ? i : b, 0);

  function crossings(out, lo, hi, a, b) {
    const k = idx(lo, hi), sa = smooth(dbArr(out[a])), sb = smooth(dbArr(out[b]));
    const da = Float64Array.from(sa, (v, i) => v - sb[i]);
    const xs = k.slice(0, -1).filter(i => Math.sign(da[i]) !== Math.sign(da[i + 1]));
    if (!xs.length) return null;
    const c = Math.sqrt(lo * hi);
    return f[xs.reduce((p, i) => Math.abs(Math.log(f[i] / c)) < Math.abs(Math.log(f[p] / c)) ? i : p, xs[0])];
  }
  function metrics(des, box = null) {
    const cfg = boxConfig(des.box);
    box = box || boxRatio(cfg);
    const res = {};
    let on;
    for (const ang of ["on", "off30"]) {
      const out = evaluate(des, ang, box);
      if (ang === "on") on = out;
      const ys = smooth(dbArr(out.sum)), y = K.map(i => ys[i]);
      const mean = y.reduce((a, b) => a + b, 0) / y.length;
      res[ang] = {
        spread: Math.max(...y) - Math.min(...y),
        rms: Math.sqrt(y.reduce((a, v) => a + (v - mean) ** 2, 0) / y.length),
        level: median(y),
      };
    }
    res.x_wm = crossings(on, 150, 900, "woof", "mid");
    res.x_mt = crossings(on, 1400, 6000, "mid", "tw");
    let zmin = Infinity;
    for (let i = 0; i < N; i++) if (f[i] > 200 && f[i] < 15000) zmin = Math.min(zmin, C.abs(on.Zamp2, i));
    res.Zamp2_min = zmin;
    res.twAtFs = db(on.tw, iFs) - res.on.level;

    // A-weighted pink-noise loudness estimate (for IEC 60268-13 level matching)
    let pinkEnergy = 0, wSum = 0;
    for (let i = 1; i < N; i++) {
      const fx = f[i], df = f[i] - f[i - 1];
      if (fx < 40 || fx > 16000) continue;
      const f2 = fx * fx;
      const ra = (12194 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * Math.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2)) * (f2 + 12194 ** 2));
      const aWeight = ra * ra;
      const mag2 = on.sum.re[i] ** 2 + on.sum.im[i] ** 2;
      pinkEnergy += mag2 * aWeight * (df / fx);
      wSum += aWeight * (df / fx);
    }
    res.loudnessdBA = 10 * Math.log10(pinkEnergy / (wSum || 1) + 1e-18);
    return res;
  }

  // ---------------------------------------------------------------- Distance-Compensated & LF-Spliced Full-Spectrum Model
  // Precompute distance-compensated (d = -1.15 m, c = 345 m/s) Lab E TFs so interpolation to arbitrary
  // FFT bins has smooth unwrapped phase and zero chord-shortening.
  const D_COMP = -1.15, C_COMP = 345.0;
  const TF_COMP = { on: {}, off30: {} };
  for (const a of ["on", "off30"]) {
    for (const u of ["woof", "mid", "tw"]) {
      const z = TF[a][u], c = C.make(N), mag = new Float64Array(N), ph = new Float64Array(N);
      for (let i = 0; i < N; i++) {
        const ang = TWO_PI * f[i] * D_COMP / C_COMP;
        const rot = mul([z.re[i], z.im[i]], [Math.cos(ang), Math.sin(ang)]);
        c.re[i] = rot[0]; c.im[i] = rot[1];
        mag[i] = Math.hypot(rot[0], rot[1]);
        ph[i] = Math.atan2(rot[1], rot[0]);
      }
      // Unwrap phase along the Lab E grid
      for (let i = 1; i < N; i++) {
        let dp = ph[i] - ph[i - 1];
        while (dp > Math.PI) dp -= TWO_PI;
        while (dp < -Math.PI) dp += TWO_PI;
        ph[i] = ph[i - 1] + dp;
      }
      TF_COMP[a][u] = { re: c.re, im: c.im, mag, ph };
    }
  }

  // Anchor factor between Task 1 closed-box p1m(f) and Lab E distance-compensated woofer TF in [120, 160] Hz
  const kAnchorIdx = idx(120, 160);
  let anchorMagRatio = 0, anchorPhaseOffset = 0;
  for (const i of kAnchorIdx) {
    const mLab = TF_COMP.on.woof.mag[i];
    const mBox = Math.hypot(closedRef.re[i], closedRef.im[i]);
    anchorMagRatio += mLab / (mBox || 1e-12);
    const pLab = TF_COMP.on.woof.ph[i];
    const pBox = Math.atan2(closedRef.im[i], closedRef.re[i]);
    let dp = pLab - pBox;
    while (dp > Math.PI) dp -= TWO_PI;
    while (dp < -Math.PI) dp += TWO_PI;
    anchorPhaseOffset += dp;
  }
  anchorMagRatio /= kAnchorIdx.length;
  anchorPhaseOffset /= kAnchorIdx.length;

  function interpGrid(fx, arrMag, arrPh) {
    if (fx <= f[0]) return [arrMag[0] * Math.cos(arrPh[0]), arrMag[0] * Math.sin(arrPh[0])];
    if (fx >= f[N - 1]) return [arrMag[N - 1] * Math.cos(arrPh[N - 1]), arrMag[N - 1] * Math.sin(arrPh[N - 1])];
    let lo = 0, hi = N - 1;
    while (hi - lo > 1) {
      const m = (lo + hi) >> 1;
      if (f[m] <= fx) lo = m; else hi = m;
    }
    const t = Math.log(fx / f[lo]) / Math.log(f[hi] / f[lo]);
    const mag = arrMag[lo] * (1 - t) + arrMag[hi] * t;
    const ph = arrPh[lo] * (1 - t) + arrPh[hi] * t;
    return [mag * Math.cos(ph), mag * Math.sin(ph)];
  }

  function interpZi(fx, unit, idealLoad = false) {
    if (idealLoad) return [RE_NOM[unit], 0];
    const z = ZI[unit];
    if (fx <= f[0]) return [z.re[0], z.im[0]];
    if (fx >= f[N - 1]) return [z.re[N - 1], z.im[N - 1]];
    let lo = 0, hi = N - 1;
    while (hi - lo > 1) {
      const m = (lo + hi) >> 1;
      if (f[m] <= fx) lo = m; else hi = m;
    }
    const t = Math.log(fx / f[lo]) / Math.log(f[hi] / f[lo]);
    return [z.re[lo] * (1 - t) + z.re[hi] * t, z.im[lo] * (1 - t) + z.im[hi] * t];
  }

  // Evaluate full-range (e.g. 10 Hz - 24 kHz) response on any frequency vector `freqs`
  function evaluateSpectrum(freqs, des, opts = {}) {
    const n = freqs.length;
    const cfg = boxConfig(des.box);
    const bx = cfg.MAP ? ventBox(cfg.MAP, cfg.fill) : boxDict({ RAB: B.RAB, fill: cfg.fill });
    const bxClosed = boxDict({ RAB: B.RAB, fill: 1.0 });
    const simVented = boxSystem(freqs, bx).p1m;
    const simClosed = boxSystem(freqs, bxClosed).p1m;

    const dg = des.digital;
    const HL = hDigitalAt(freqs, dg.fc, "LPF", dg.align);
    const HH = hDigitalAt(freqs, dg.fc, "HPF", dg.align);
    const gw = 10 ** (dg.g_woof_dB / 20);

    const zMid = C.make(n), zTw = C.make(n);
    for (let i = 0; i < n; i++) {
      const zm = interpZi(freqs[i], "mid", opts.idealLoad);
      const zt = interpZi(freqs[i], "tw", opts.idealLoad);
      zMid.re[i] = zm[0]; zMid.im[i] = zm[1];
      zTw.re[i] = zt[0]; zTw.im[i] = zt[1];
    }
    const m = ladder(passiveParts(des.mid), zMid, des.Rdcr || 0, freqs);
    const t = ladder(passiveParts(des.tw), zTw, des.Rdcr || 0, freqs);

    const blend = typeof opts.angle === "number" ? Math.max(0, Math.min(1, opts.angle / 30)) : (opts.angle === "off30" ? 1 : 0);
    const dy = opts.listenerDy || 0;
    const useLfSplice = opts.lfSplice !== false; // default true: use validated Task 1 box model below 125 Hz
    const active = opts.active || { woof: true, mid: true, tw: true };
    const P = des.pol;

    const out = { woof: C.make(n), mid: C.make(n), tw: C.make(n), sum: C.make(n) };
    for (let i = 0; i < n; i++) {
      const fx = freqs[i];
      if (fx <= 0) continue;

      const tfInterp = u => {
        const cOn = interpGrid(fx, TF_COMP.on[u].mag, TF_COMP.on[u].ph);
        if (blend <= 0) return cOn;
        const cOff = interpGrid(fx, TF_COMP.off30[u].mag, TF_COMP.off30[u].ph);
        if (blend >= 1) return cOff;
        const m0 = Math.hypot(cOn[0], cOn[1]), m1 = Math.hypot(cOff[0], cOff[1]);
        const p0 = Math.atan2(cOn[1], cOn[0]), p1 = Math.atan2(cOff[1], cOff[0]);
        let dp = p1 - p0;
        while (dp > Math.PI) dp -= TWO_PI;
        while (dp < -Math.PI) dp += TWO_PI;
        const mag = m0 * (1 - blend) + m1 * blend, ph = p0 + blend * dp;
        return [mag * Math.cos(ph), mag * Math.sin(ph)];
      };

      // Woofer response: above 150 Hz use Lab E * (p_box / p_closed); below 90 Hz use Task 1 box model anchored at 120-160 Hz
      const pVent = get(simVented, i), pCl = get(simClosed, i);
      const ratio = div(pVent, pCl);
      const wLab = mul(tfInterp("woof"), ratio);
      let wAcoustic;
      if (useLfSplice && fx < 150) {
        const wModel = mul(pVent, [anchorMagRatio * Math.cos(anchorPhaseOffset), anchorMagRatio * Math.sin(anchorPhaseOffset)]);
        if (fx <= 85) {
          wAcoustic = wModel;
        } else {
          // Raised-cosine blend between 85 Hz and 150 Hz
          const alpha = 0.5 * (1 - Math.cos(Math.PI * (fx - 85) / (150 - 85)));
          wAcoustic = [wModel[0] * (1 - alpha) + wLab[0] * alpha, wModel[1] * (1 - alpha) + wLab[1] * alpha];
        }
      } else {
        // If LF splice is disabled, taper below 50 Hz where Lab E has no points
        const lfWin = fx < 50 ? Math.max(0, (fx - 20) / 30) ** 2 : 1;
        wAcoustic = [wLab[0] * lfWin, wLab[1] * lfWin];
      }

      // Midrange and tweeter low-frequency roll-off below Lab E measurement floor (60 Hz / 110 Hz)
      const mWin = fx < 65 ? Math.max(0, (fx - 25) / 40) ** 2 : 1;
      const tWin = fx < 120 ? Math.max(0, (fx - 60) / 60) ** 2 : 1;
      // UMIK >18.4 kHz glitch protection window (README.md: "The UMIK channel jumps about 20 dB above 18.4 kHz. Ignore the TF up there.")
      const hfWin = fx > 18000 ? (fx >= 20500 ? 0 : 0.5 * (1 + Math.cos(Math.PI * (fx - 18000) / 2500))) : 1;

      const vPhase = u => {
        if (!dy) return [1, 0];
        const g = GEOM[u], m0 = GEOM.refMic;
        const r0 = Math.hypot(m0.x - g.x, m0.y - g.y, m0.z - g.z);
        const r1 = Math.hypot(m0.x - g.x, (m0.y + dy) - g.y, m0.z - g.z);
        const dPhi = -TWO_PI * fx * (r1 - r0) / 345.0;
        return [Math.cos(dPhi), Math.sin(dPhi)];
      };

      const w = mul(mul(mul([P.woof * gw * hfWin, 0], get(HL, i)), wAcoustic), vPhase("woof"));
      const md = mul(mul(mul(mul([P.mid * mWin * hfWin, 0], get(HH, i)), get(m.T, i)), tfInterp("mid")), vPhase("mid"));
      const tw = mul(mul(mul(mul([P.tw * tWin * hfWin, 0], get(HH, i)), get(t.T, i)), tfInterp("tw")), vPhase("tw"));

      // Optional IEC 60268-13 room boundary loading (+2.2 dB shelf below 110 Hz)
      let roomGain = 1.0;
      if (opts.roomMode === "iec") {
        const shelf = 1 + 0.28 / (1 + (fx / 95) ** 2);
        roomGain = shelf;
      }

      const wF = [w[0] * roomGain, w[1] * roomGain];
      const mdF = [md[0] * roomGain, md[1] * roomGain];
      const twF = [tw[0] * roomGain, tw[1] * roomGain];
      let s = [
        (active.woof ? wF[0] : 0) + (active.mid ? mdF[0] : 0) + (active.tw ? twF[0] : 0),
        (active.woof ? wF[1] : 0) + (active.mid ? mdF[1] : 0) + (active.tw ? twF[1] : 0),
      ];
      if (opts.linearPhase) {
        s = [Math.hypot(s[0], s[1]), 0];
      }
      out.woof.re[i] = wF[0]; out.woof.im[i] = wF[1];
      out.mid.re[i] = mdF[0]; out.mid.im[i] = mdF[1];
      out.tw.re[i] = twF[0]; out.tw.im[i] = twF[1];
      out.sum.re[i] = s[0]; out.sum.im[i] = s[1];
    }
    return out;
  }

  // ---------------------------------------------------------------- Radix-2 FFT / IFFT & FIR Impulse Response Synthesis
  function fftRadix2(re, im, inverse = false) {
    const n = re.length;
    for (let i = 1, j = 0; i < n; i++) {
      let bit = n >> 1;
      for (; j & bit; bit >>= 1) j ^= bit;
      j ^= bit;
      if (i < j) {
        let t = re[i]; re[i] = re[j]; re[j] = t;
        t = im[i]; im[i] = im[j]; im[j] = t;
      }
    }
    for (let len = 2; len <= n; len <<= 1) {
      const half = len >> 1;
      const ang = (inverse ? TWO_PI : -TWO_PI) / len;
      const wlenRe = Math.cos(ang), wlenIm = Math.sin(ang);
      for (let i = 0; i < n; i += len) {
        let wRe = 1, wIm = 0;
        for (let j = 0; j < half; j++) {
          const uRe = re[i + j], uIm = im[i + j];
          const vRe = re[i + j + half] * wRe - im[i + j + half] * wIm;
          const vIm = re[i + j + half] * wIm + im[i + j + half] * wRe;
          re[i + j] = uRe + vRe; im[i + j] = uIm + vIm;
          re[i + j + half] = uRe - vRe; im[i + j + half] = uIm - vIm;
          const nextRe = wRe * wlenRe - wIm * wlenIm;
          wIm = wRe * wlenIm + wIm * wlenRe;
          wRe = nextRe;
        }
      }
    }
    if (inverse) {
      for (let i = 0; i < n; i++) { re[i] /= n; im[i] /= n; }
    }
  }

  // Reference level normalization: passband level of Group 10 default design = 0 dB (gain 1.0)
  const refMetrics = metrics(D.design);
  const REF_PASSBAND_GAIN = 10 ** (-refMetrics.on.level / 20);

  function synthesizeIR(des, opts = {}) {
    const sampleRate = opts.sampleRate || 48000;
    const nfft = opts.nfft || 8192;
    const half = nfft >> 1;
    const preDelaySec = opts.preDelaySec ?? 0.020; // 20 ms causal center so acausal/filter rings never wrap

    const freqs = new Float64Array(half + 1);
    for (let k = 0; k <= half; k++) freqs[k] = k * sampleRate / nfft;

    const spec = evaluateSpectrum(freqs, des, opts);
    const offSpec = opts.roomMode === "iec" ? evaluateSpectrum(freqs, des, Object.assign({}, opts, { angle: 30, roomMode: "anechoic" })) : null;

    // Optional loudness-match trim vs reference design
    let gainScale = REF_PASSBAND_GAIN;
    if (opts.loudnessMatch) {
      const m = metrics(des);
      const dLUFS = refMetrics.loudnessdBA - m.loudnessdBA;
      gainScale *= 10 ** (Math.max(-12, Math.min(12, dLUFS)) / 20);
    }

    const re = new Float64Array(nfft), im = new Float64Array(nfft);
    const reOff = offSpec ? new Float64Array(nfft) : null, imOff = offSpec ? new Float64Array(nfft) : null;

    for (let k = 1; k < half; k++) {
      const fx = freqs[k];
      // Subsonic 4th-order high-pass below 14 Hz to prevent DC / sub-10 Hz offset
      const hpSub = 1 / Math.sqrt(1 + (14 / Math.max(1, fx)) ** 8);
      const shift = -TWO_PI * fx * preDelaySec;
      const cShift = [Math.cos(shift) * hpSub * gainScale, Math.sin(shift) * hpSub * gainScale];

      const h = mul([spec.sum.re[k], spec.sum.im[k]], cShift);
      re[k] = h[0]; im[k] = h[1];
      re[nfft - k] = h[0]; im[nfft - k] = -h[1];

      if (offSpec) {
        const hOff = mul([offSpec.sum.re[k], offSpec.sum.im[k]], cShift);
        reOff[k] = hOff[0]; imOff[k] = hOff[1];
        reOff[nfft - k] = hOff[0]; imOff[nfft - k] = -hOff[1];
      }
    }

    fftRadix2(re, im, true);
    if (offSpec) fftRadix2(reOff, imOff, true);

    // Apply smooth causal taper window at edges of the NFFT buffer
    const ir = new Float32Array(nfft);
    const fadeIn = Math.floor(0.004 * sampleRate);
    const fadeOut = Math.floor(0.025 * sampleRate);
    for (let n = 0; n < nfft; n++) {
      let w = 1.0;
      if (n < fadeIn) w = 0.5 * (1 - Math.cos(Math.PI * n / fadeIn));
      else if (n > nfft - fadeOut) w = 0.5 * (1 - Math.cos(Math.PI * (nfft - n) / fadeOut));
      ir[n] = re[n] * w;
    }

    // If IEC 60268-13 room mode is enabled, add early reflections (floor bounce at 1.9 ms, side walls at 4.8 & 6.3 ms,
    // ceiling at 7.4 ms) weighted by the 30° off-axis speaker response!
    if (offSpec) {
      const reflections = [
        { delayMs: 1.85, gain: 0.22, sign: 1 },   // floor bounce
        { delayMs: 4.70, gain: 0.16, sign: 1 },   // left wall
        { delayMs: 6.15, gain: 0.14, sign: -1 },  // right wall
        { delayMs: 7.60, gain: 0.11, sign: 1 },   // ceiling
        { delayMs: 11.8, gain: 0.08, sign: -1 },  // rear wall early
        { delayMs: 17.4, gain: 0.05, sign: 1 },   // diffuse cluster 1
        { delayMs: 24.9, gain: 0.035, sign: 1 },  // diffuse cluster 2
      ];
      for (const r of reflections) {
        const dSamples = Math.round((r.delayMs / 1000) * sampleRate);
        for (let n = dSamples; n < nfft; n++) {
          ir[n] += r.sign * r.gain * reOff[n - dSamples];
        }
      }
    }

    // Compute step response s[n] = sum_{m<=n} ir[m]
    const step = new Float32Array(nfft);
    let acc = 0;
    for (let n = 0; n < nfft; n++) {
      acc += ir[n];
      step[n] = acc;
    }

    return { ir, step, sampleRate, preDelaySec, freqs, spec };
  }

  // Group delay tau_g(f) = -1/(2*pi) * d(phi)/df in milliseconds on the Lab E grid
  function groupDelayMs(z) {
    const ph = new Float64Array(N);
    for (let i = 0; i < N; i++) {
      const ang = TWO_PI * f[i] * D_COMP / C_COMP;
      const rot = mul([z.re[i], z.im[i]], [Math.cos(ang), Math.sin(ang)]);
      ph[i] = Math.atan2(rot[1], rot[0]);
    }
    for (let i = 1; i < N; i++) {
      let dp = ph[i] - ph[i - 1];
      while (dp > Math.PI) dp -= TWO_PI;
      while (dp < -Math.PI) dp += TWO_PI;
      ph[i] = ph[i - 1] + dp;
    }
    const gd = new Float64Array(N);
    for (let i = 0; i < N; i++) {
      const i0 = Math.max(0, i - 2), i1 = Math.min(N - 1, i + 2);
      const dphi = ph[i1] - ph[i0], df = f[i1] - f[i0];
      gd[i] = (-dphi / (TWO_PI * df)) * 1000;
    }
    return gd;
  }

  // ---------------------------------------------------------------- Task 4 Statistical Analysis & LaTeX Export
  function analyzeListeningTrials(trials) {
    // trials: array of { subject, track, pref ('A'|'B'|'none'), scoresA: {bass, mid, treble, overall}, scoresB: {bass, mid, treble, overall}, abxCorrect?: boolean, comment?: string }
    const n = trials.length;
    const counts = { A: 0, B: 0, none: 0 };
    const attrs = ["bass", "mid", "treble", "overall"];
    const stats = { A: {}, B: {}, diff: {} };
    for (const k of attrs) { stats.A[k] = []; stats.B[k] = []; stats.diff[k] = []; }

    let abxTotal = 0, abxHits = 0;
    for (const t of trials) {
      if (t.pref && counts[t.pref] !== undefined) counts[t.pref]++;
      if (typeof t.abxCorrect === "boolean") {
        abxTotal++;
        if (t.abxCorrect) abxHits++;
      }
      if (t.scoresA && t.scoresB) {
        for (const k of attrs) {
          const va = +t.scoresA[k], vb = +t.scoresB[k];
          if (isFinite(va) && isFinite(vb)) {
            stats.A[k].push(va);
            stats.B[k].push(vb);
            stats.diff[k].push(va - vb);
          }
        }
      }
    }

    const summarize = arr => {
      if (!arr.length) return { mean: 0, sd: 0, ci95: 0, n: 0 };
      const m = arr.reduce((a, b) => a + b, 0) / arr.length;
      const v = arr.length > 1 ? arr.reduce((a, b) => a + (b - m) ** 2, 0) / (arr.length - 1) : 0;
      const sd = Math.sqrt(v);
      const tVal = arr.length <= 5 ? 2.571 : arr.length <= 10 ? 2.228 : 1.96;
      return { mean: m, sd, ci95: tVal * sd / Math.sqrt(arr.length), n: arr.length };
    };

    const summary = { A: {}, B: {}, diff: {} };
    for (const k of attrs) {
      summary.A[k] = summarize(stats.A[k]);
      summary.B[k] = summarize(stats.B[k]);
      summary.diff[k] = summarize(stats.diff[k]);
    }

    // One-sided exact binomial p-value for ABX (H0: p = 0.5) and preference A vs B
    function binomPValue(k, total) {
      if (total <= 0 || k <= 0) return 1.0;
      let p = 0;
      for (let i = k; i <= total; i++) {
        let c = 1;
        for (let j = 1; j <= i; j++) c = c * (total - j + 1) / j;
        p += c * (0.5 ** total);
      }
      return Math.min(1, p);
    }

    const prefDecided = counts.A + counts.B;
    const prefP = binomPValue(Math.max(counts.A, counts.B), prefDecided);
    const abxP = binomPValue(abxHits, abxTotal);

    function toLatex(labelA = "Design A (Group 10)", labelB = "Design B (Variant)") {
      const names = { bass: "Bass quantity", mid: "Midrange naturalness", treble: "Treble brightness", overall: "Overall quality" };
      const rows = attrs.map(k => {
        const a = summary.A[k], b = summary.B[k], d = summary.diff[k];
        return `${names[k]} & $${a.mean.toFixed(2)} \\pm ${a.ci95.toFixed(2)}$ & $${b.mean.toFixed(2)} \\pm ${b.ci95.toFixed(2)}$ & $${d.mean >= 0 ? "+" : ""}${d.mean.toFixed(2)}$ \\\\`;
      }).join("\n");
      return `% Generated by Auralis — Task 4 IEC 60268-13 Listening Test Suite
\\newcommand{\\tFourTrials}{${n}}
\\newcommand{\\tFourPrefA}{${counts.A}}
\\newcommand{\\tFourPrefB}{${counts.B}}
\\newcommand{\\tFourPrefNone}{${counts.none}}
\\newcommand{\\tFourPrefP}{${prefP.toFixed(3)}}
% Table for Project_report.tex Section 4:
\\begin{center}
\\begin{tabular}{lccc}
\\toprule
Attribute (1--5 scale) & ${labelA} & ${labelB} & $\\Delta (A - B)$ \\\\
\\midrule
${rows}
\\midrule
Preference count & ${counts.A} & ${counts.B} & No pref: ${counts.none} ($p = ${prefP.toFixed(3)}$) \\\\
\\bottomrule
\\end{tabular}
\\end{center}`;
    }

    return { n, counts, summary, prefP, abxTotal, abxHits, abxP, toLatex };
  }

  function minidspText(f0, kind, align) {
    return sections(f0, kind, align).map(([b0, b1, b2, a1, a2], k) =>
      `\n biquad${k + 1}, \n b0 = ${b0.toFixed(15)}, \n b1 = ${b1.toFixed(15)}, \n b2 = ${b2.toFixed(15)}, ` +
      `\n a1 = ${(-a1).toFixed(15)}, \n a2 = ${(-a2).toFixed(15)}, `).join("");
  }

  function g15(x) {
    if (x === 0) return "0";
    const [m, e] = x.toExponential(14).split("e"), ex = parseInt(e, 10);
    if (ex < -4 || ex >= 15) {
      const mm = m.replace(/\.?0+$/, "");
      return `${mm}e${ex < 0 ? "-" : "+"}${String(Math.abs(ex)).padStart(2, "0")}`;
    }
    let s = x.toPrecision(15);
    if (s.includes(".")) s = s.replace(/0+$/, "").replace(/\.$/, "");
    return s;
  }

  function ltspiceText(f0, kind, align) {
    const T = g15(1 / FS);
    return sections(f0, kind, align).map(([b0, b1, b2, a1, a2]) =>
      `Laplace=(${g15(b0)}+${g15(b1)}*exp(-s*${T})+${g15(b2)}*exp(-2*s*${T}))/(1+${g15(a1)}*exp(-s*${T})+${g15(a2)}*exp(-2*s*${T}))`);
  }

  function encodeWAV(samples, sampleRate = 48000) {
    const numSamples = samples.length;
    const buffer = new ArrayBuffer(44 + numSamples * 2);
    const view = new DataView(buffer);
    const writeStr = (off, s) => { for (let i = 0; i < s.length; i++) view.setUint8(off + i, s.charCodeAt(i)); };
    writeStr(0, "RIFF");
    view.setUint32(4, 36 + numSamples * 2, true);
    writeStr(8, "WAVE");
    writeStr(12, "fmt ");
    view.setUint32(16, 16, true);
    view.setUint16(20, 1, true); // PCM 16-bit
    view.setUint16(22, 1, true); // mono
    view.setUint32(24, sampleRate, true);
    view.setUint32(28, sampleRate * 2, true);
    view.setUint16(32, 2, true);
    view.setUint16(34, 16, true);
    writeStr(36, "data");
    view.setUint32(40, numSamples * 2, true);
    let peak = 0;
    for (let i = 0; i < numSamples; i++) peak = Math.max(peak, Math.abs(samples[i]));
    const scale = peak > 0.99 ? 0.98 / peak : 1.0;
    for (let i = 0; i < numSamples; i++) {
      const s = Math.max(-1, Math.min(1, samples[i] * scale));
      view.setInt16(44 + i * 2, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
    }
    return new Uint8Array(buffer);
  }

  const TRACK_LIST = [
    { id: "ensemble", name: "1 · Full Studio Reference (Bass, Rhodes, Guitar & Drums)", focus: "Full range · 30 Hz – 16 kHz · Holistic IEC A/B balance", duration: 8.0 },
    { id: "bass_groove", name: "2 · Sub & Port Groove (Bassline E1–G0 + Kick)", focus: "Task 1 Box Tuning · 24 Hz – 250 Hz · Vent extension vs ripple", duration: 8.0 },
    { id: "vocal_keys", name: "3 · Baritone Formant & Warm Keys (Vocal + Rhodes)", focus: "Woofer/Mid Crossover · 100 Hz – 2.5 kHz · 325 Hz LR4 handoff", duration: 8.0 },
    { id: "guitar_cymbal", name: "4 · Acoustic Guitar & Brushed Cymbals", focus: "Mid/Tweeter Crossover · 400 Hz – 16 kHz · 2.86 kHz & L-pad", duration: 8.0 },
    { id: "pink_noise", name: "5 · IEC 60268-13 Pink Noise (20 Hz – 20 kHz)", focus: "Tonal balance, off-axis dispersion & polarity notch check", duration: 6.0 },
    { id: "xover_noise", name: "6 · Dual Crossover Band-Noise (350 Hz & 2.86 kHz)", focus: "Isolates WM & MT crossover zones · Flip polarity to hear null", duration: 6.0 },
    { id: "log_sweep", name: "7 · Synchronized Log Sine Sweep (20 Hz → 18 kHz)", focus: "Live frequency cursor tracking across all 3 drivers", duration: 8.0 },
    { id: "tone_burst", name: "8 · Linkwitz Tone Bursts (40 Hz / 350 Hz / 2.86 kHz)", focus: "Transient overhang, port ringing & group delay check", duration: 6.0 },
  ];

  function generateTrackSamples(trackId, sampleRate = 48000) {
    const meta = TRACK_LIST.find(t => t.id === trackId) || TRACK_LIST[0];
    const len = Math.floor(meta.duration * sampleRate);
    const out = new Float32Array(len);
    // Deterministic PRNG so tracks are 100% repeatable across runs
    let seed = 0x243F6A88;
    const rand = () => {
      seed ^= seed << 13; seed ^= seed >>> 17; seed ^= seed << 5;
      return ((seed >>> 0) / 4294967296) * 2 - 1;
    };

    const addNote = (t0, dur, f0, amp, harmonics, decay = 5.0) => {
      const n0 = Math.floor(t0 * sampleRate), n1 = Math.min(len, Math.floor((t0 + dur) * sampleRate));
      const att = Math.min(0.008, dur * 0.1) * sampleRate;
      for (let i = n0; i < n1; i++) {
        const dt = (i - n0) / sampleRate;
        const env = ((i - n0) < att ? (i - n0) / att : 1.0) * Math.exp(-decay * dt);
        let s = 0;
        for (let h = 0; h < harmonics.length; h++) {
          const fh = f0 * (h + 1);
          if (fh < sampleRate * 0.45) {
            s += harmonics[h] * Math.sin(TWO_PI * fh * dt) * Math.exp(-0.6 * h * dt);
          }
        }
        out[i] += amp * env * s;
      }
    };

    const addKick = (t0, amp = 0.55) => {
      const n0 = Math.floor(t0 * sampleRate), n1 = Math.min(len, n0 + Math.floor(0.32 * sampleRate));
      let ph = 0;
      for (let i = n0; i < n1; i++) {
        const dt = (i - n0) / sampleRate;
        const fInst = 44 + 115 * Math.exp(-dt * 38);
        ph += TWO_PI * fInst / sampleRate;
        const body = Math.sin(ph) * Math.exp(-dt * 11);
        const click = Math.sin(TWO_PI * 2400 * dt) * Math.exp(-dt * 180) * 0.25;
        out[i] += amp * (body + click);
      }
    };

    const addSnareAndHat = (t0, isSnare, amp = 0.25) => {
      const dur = isSnare ? 0.22 : 0.08;
      const n0 = Math.floor(t0 * sampleRate), n1 = Math.min(len, n0 + Math.floor(dur * sampleRate));
      let bp1 = 0, bp2 = 0;
      for (let i = n0; i < n1; i++) {
        const dt = (i - n0) / sampleRate;
        const w = rand();
        // High-frequency metallic resonance + noise
        const metal = (Math.sin(TWO_PI * 3420 * dt) + 0.7 * Math.sin(TWO_PI * 5890 * dt) + 0.5 * Math.sin(TWO_PI * 8340 * dt)) * w;
        bp1 = 0.65 * bp1 + 0.35 * (w - bp2);
        bp2 = 0.85 * bp2 + 0.15 * bp1;
        const shell = isSnare ? Math.sin(TWO_PI * 185 * dt) * Math.exp(-dt * 28) * 0.6 : 0;
        const noiseEnv = Math.exp(-dt * (isSnare ? 18 : 48));
        out[i] += amp * (shell + (0.65 * (w - bp1) + 0.35 * metal) * noiseEnv);
      }
    };

    const addFormantNote = (t0, dur, f0, formants, amp = 0.28) => {
      const n0 = Math.floor(t0 * sampleRate), n1 = Math.min(len, Math.floor((t0 + dur) * sampleRate));
      let ph = 0;
      for (let i = n0; i < n1; i++) {
        const dt = (i - n0) / sampleRate;
        const env = Math.sin(Math.PI * Math.min(1, dt / 0.06)) * Math.sin(Math.PI * Math.min(1, (dur - dt) / 0.08));
        const vib = 1 + 0.004 * Math.sin(TWO_PI * 5.4 * dt);
        const fCur = f0 * vib;
        ph += fCur / sampleRate;
        let s = 0;
        for (let k = 1; k <= 24; k++) {
          const fk = k * fCur;
          if (fk >= sampleRate * 0.45) break;
          let g = 1 / (k ** 0.75);
          for (const [ff, bw, fg] of formants) {
            g += fg * Math.exp(-(((fk - ff) / bw) ** 2));
          }
          s += (g * 0.08) * Math.sin(TWO_PI * k * ph);
        }
        out[i] += amp * env * s;
      }
    };

    if (trackId === "ensemble") {
      const beat = 0.5; // 120 BPM, 16 beats in 8.0 s
      const bassNotes = [
        [0, 1.5, 41.20], [1.5, 0.5, 49.00], [2.0, 1.5, 55.00], [3.5, 0.5, 61.74],
        [4.0, 1.5, 36.71], [5.5, 0.5, 41.20], [6.0, 1.5, 32.70], [7.5, 0.5, 36.71],
      ];
      for (const [b, d, fn] of bassNotes) {
        addNote(b * beat, d * beat, fn, 0.42, [1.0, 0.75, 0.45, 0.25, 0.12], 3.2);
      }
      const chords = [
        [0, 4, [164.81, 196.00, 246.94, 293.66, 369.99]], // Em9
        [4, 4, [130.81, 196.00, 246.94, 293.66, 329.63]], // Cmaj9
        [8, 4, [110.00, 164.81, 196.00, 246.94, 261.63]], // Am9
        [12, 4, [123.47, 185.00, 220.00, 293.66, 369.99]], // Bm7
      ];
      for (const [b, d, notes] of chords) {
        for (const fn of notes) addNote(b * beat, d * beat, fn, 0.085, [1.0, 0.25, 0.08, 0.03], 1.6);
      }
      const arp = [329.63, 392.00, 493.88, 587.33, 659.25, 587.33, 493.88, 392.00];
      for (let step = 0; step < 32; step++) {
        const fn = arp[step % arp.length] * (step >= 16 ? 0.8909 : 1.0);
        addNote(step * 0.25, 0.35, fn, 0.14, [1.0, 0.65, 0.4, 0.28, 0.18, 0.12, 0.08, 0.05], 6.5);
      }
      for (let b = 0; b < 16; b++) {
        if (b % 2 === 0) addKick(b * beat, 0.48);
        if (b % 2 === 1) addSnareAndHat(b * beat, true, 0.22);
        addSnareAndHat(b * beat, false, 0.11);
        addSnareAndHat((b + 0.5) * beat, false, 0.08);
      }
    } else if (trackId === "bass_groove") {
      // Deep sub & port resonance test (walks down from 55 Hz -> 41.2 Hz -> 36.7 Hz -> 32.7 Hz -> 27.5 Hz -> 24.5 Hz!)
      const seq = [
        [0.0, 0.9, 55.00], [1.0, 0.9, 49.00], [2.0, 0.9, 41.20], [3.0, 0.9, 36.71],
        [4.0, 0.9, 32.70], [5.0, 0.9, 30.87], [6.0, 0.9, 27.50], [7.0, 0.95, 24.50],
      ];
      for (const [t0, dur, fn] of seq) {
        addNote(t0, dur, fn, 0.58, [1.0, 0.55, 0.28, 0.12], 2.2);
        addKick(t0, 0.45);
        addKick(t0 + 0.5, 0.32);
      }
    } else if (trackId === "vocal_keys") {
      // Baritone voice & Rhodes chords centered on the 325 Hz woofer/midrange crossover
      const vowels = [
        [0.0, 2.0, 130.81, [[730, 90, 3.0], [1090, 110, 2.0], [2440, 160, 1.0]]], // /a/
        [2.0, 2.0, 146.83, [[570, 80, 3.0], [840, 100, 1.8], [2410, 150, 0.8]]],  // /o/
        [4.0, 2.0, 164.81, [[530, 80, 2.8], [1840, 130, 2.2], [2480, 160, 1.1]]], // /e/
        [6.0, 2.0, 123.47, [[660, 85, 3.0], [1720, 120, 2.0], [2410, 150, 1.0]]], // /ae/
      ];
      for (const [t0, dur, f0, fm] of vowels) {
        addFormantNote(t0, dur, f0, fm, 0.42);
        for (const mulF of [1.0, 1.25, 1.5, 1.875]) {
          addNote(t0, dur, f0 * 2 * mulF, 0.08, [1.0, 0.3, 0.08], 1.5);
        }
      }
    } else if (trackId === "guitar_cymbal") {
      // Nylon guitar & brushed cymbals spanning 2.86 kHz mid/tweeter crossover & 1.45 kHz tweeter fs
      const notes = [220, 277.18, 329.63, 440, 554.37, 659.25, 880, 659.25, 554.37, 440, 329.63, 277.18, 246.94, 329.63, 493.88, 739.99];
      for (let i = 0; i < 32; i++) {
        const t0 = i * 0.25, fn = notes[i % notes.length];
        addNote(t0, 0.42, fn, 0.24, [1.0, 0.85, 0.65, 0.50, 0.38, 0.28, 0.20, 0.15, 0.10, 0.07], 5.5);
        if (i % 2 === 0) addSnareAndHat(t0, false, 0.18);
        if (i % 4 === 2) addSnareAndHat(t0 + 0.125, false, 0.12);
      }
    } else if (trackId === "pink_noise") {
      // Paul Kellet's precision -3 dB/oct pink noise filter
      let b0 = 0, b1 = 0, b2 = 0, b3 = 0, b4 = 0, b5 = 0, b6 = 0;
      for (let i = 0; i < len; i++) {
        const w = rand();
        b0 = 0.99886 * b0 + w * 0.0555179;
        b1 = 0.99332 * b1 + w * 0.0750759;
        b2 = 0.96900 * b2 + w * 0.1538520;
        b3 = 0.86650 * b3 + w * 0.3104856;
        b4 = 0.55000 * b4 + w * 0.5329522;
        b5 = -0.7616 * b5 - w * 0.0168980;
        out[i] = (b0 + b1 + b2 + b3 + b4 + b5 + b6 + w * 0.5362) * 0.05;
        b6 = w * 0.115926;
      }
    } else if (trackId === "xover_noise") {
      // Band-limited noise centered around WM (~350 Hz) and MT (~2860 Hz) crossovers
      const [b0L, b1L, b2L, a1L, a2L] = bq(350, 2.2, "LPF");
      let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
      let ph1 = 0, ph2 = 0;
      for (let i = 0; i < len; i++) {
        const w = rand();
        const y = b0L * w + b1L * x1 + b2L * x2 - a1L * y1 - a2L * y2;
        x2 = x1; x1 = w; y2 = y1; y1 = y;
        ph1 += TWO_PI * 350 / sampleRate;
        ph2 += TWO_PI * 2860 / sampleRate;
        out[i] = y * Math.cos(ph1) * 0.6 + y * Math.cos(ph2) * 0.45;
      }
    } else if (trackId === "log_sweep") {
      // Phase-coherent exponential sine sweep 20 Hz -> 18 kHz over 8.0 s
      const f1 = 20, f2 = 18000, T = meta.duration;
      const L = T / Math.log(f2 / f1);
      for (let i = 0; i < len; i++) {
        const t = i / sampleRate;
        const env = t < 0.05 ? t / 0.05 : (t > T - 0.08 ? (T - t) / 0.08 : 1.0);
        out[i] = 0.5 * env * Math.sin(TWO_PI * f1 * L * (Math.exp(t / L) - 1));
      }
    } else if (trackId === "tone_burst") {
      // Alternating Linkwitz 5-cycle Hann-windowed tone bursts at 40 Hz, 350 Hz, 1000 Hz, 2860 Hz
      const bursts = [
        [0.2, 40, 6], [1.7, 350, 8], [3.0, 1000, 10], [4.3, 2860, 12],
      ];
      for (const [t0, fb, cycles] of bursts) {
        const dur = cycles / fb;
        const n0 = Math.floor(t0 * sampleRate), n1 = Math.min(len, Math.floor((t0 + dur) * sampleRate));
        for (let i = n0; i < n1; i++) {
          const dt = (i - n0) / sampleRate;
          const w = 0.5 * (1 - Math.cos(TWO_PI * dt / dur));
          out[i] += 0.65 * w * Math.sin(TWO_PI * fb * dt);
        }
      }
    }

    // Peak-normalize to 0.75 (-2.5 dBFS) so convolution with +3 dB crossover peaks never clips
    let peak = 0;
    for (let i = 0; i < len; i++) peak = Math.max(peak, Math.abs(out[i]));
    if (peak > 1e-9) {
      const g = 0.72 / peak;
      for (let i = 0; i < len; i++) out[i] *= g;
    }
    // Smooth 15 ms loop boundary crossfade
    const fade = Math.min(Math.floor(0.015 * sampleRate), len >> 2);
    for (let i = 0; i < fade; i++) {
      const w = 0.5 * (1 - Math.cos(Math.PI * i / fade));
      out[i] *= w;
      out[len - 1 - i] *= w;
    }
    return out;
  }

  return {
    f, N, B, TF, ZI, RE_NOM, GEOM, TOPOLOGIES, TRACK_LIST,
    boxDict, ventBox, boxSystem, boxConfig, boxRatio, f3Ripple,
    hDigital, hDigitalAt, passiveParts, ladder,
    evaluate, evaluateSpectrum, smooth, dbArr, metrics,
    fftRadix2, synthesizeIR, groupDelayMs, analyzeListeningTrials,
    minidspText, ltspiceText, encodeWAV, generateTrackSamples,
  };
}
