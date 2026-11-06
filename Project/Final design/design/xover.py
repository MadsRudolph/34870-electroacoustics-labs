#!/usr/bin/env python3
"""System D crossover engine: the whole of Figure 1 computed from the measured data.

    python3 xover.py                 # evaluate the design in design.json, print the report
    python3 xover.py --optimise      # search the digital and passive parts (Appendix 1 values)
    python3 xover.py --plots         # figures into ../figures/xover_*.png
    python3 xover.py --export        # MiniDSP + LTspice strings into ../data/dsp/, the bundle for the app

Signal chain, per unit, for 1 V at the MiniDSP input:
    woofer   : H_LP(f) * g_woof * TF_woof(f) * B(f)
    midrange : H_HP(f) * T_mid(f) * TF_mid(f)          T = V_driver / V_amp of the passive LPF, loaded by Zi_mid
    tweeter  : H_HP(f) * T_tw(f)  * TF_tw(f)           passive HPF (+ L-pad), loaded by Zi_tw
and the system response is the complex sum (polarity p = +/-1 per unit). TF = Lab E p/V (same run, so
the relative phase is real), Zi = Lab D. B(f) puts the Task 1 box tuning on the woofer: Lab E had
the vent plugged, so the measured woofer is multiplied by p_vented/p_closed from the fitted box model.

Digital filters are evaluated exactly as the MiniDSP runs them: RBJ biquads at fs = 96 kHz
(the BQ function in DigitalCrossover.m), H(e^{jwT}). 'BW2'/'BW4' are what DigitalCrossover.m gives
for n = 2/4; 'LR4' is two identical BW2 sections (Q = 0.707) in cascade.
"""
import json, math, pathlib, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
CSV = PROJ / "data" / "csv"
FS = 96e3

# Appendix 1 of the guide: the only values we may use
L_STD = [0.15e-3, 0.18e-3, 0.22e-3, 0.33e-3, 0.39e-3, 0.47e-3, 0.56e-3, 0.68e-3, 0.82e-3,
         1.0e-3, 1.2e-3, 1.5e-3, 1.8e-3, 2.2e-3]
R_STD = [1.0, 1.5, 2.2, 3.3, 4.7, 5.6, 6.8, 8.2, 10, 15, 22, 33, 47]
C_STD = [1.5e-6, 2.2e-6, 2.7e-6, 3.3e-6, 3.9e-6, 4.7e-6, 5.6e-6, 6.8e-6, 8.2e-6, 10e-6, 12e-6,
         15e-6, 22e-6, 33e-6, 47e-6, 68e-6, 100e-6]


def load(name):
    m = np.genfromtxt(CSV / f"{name}.csv", delimiter=",", names=True)
    return m["f"], m["re"] + 1j * m["im"]


class Data:
    """Everything on the Lab E frequency grid (50 Hz - 19.7 kHz, 412 points)."""
    def __init__(self, box_ratio=True):
        self.f, _ = load("TF_on_woofer")
        f = self.f
        self.tf = {a: {u: load(f"TF_{a}_{n}")[1] for u, n in (("woof", "woofer"), ("mid", "midrange"), ("tw", "tweeter"))}
                   for a in ("on", "off30")}
        self.zi = {}
        for u, n in (("mid", "midrange"), ("tw", "tweeter")):
            fz, Z = load(f"Z_{n}")
            # Lab D grid -> Lab E grid (real and imaginary parts, linear in log f; the tweeter starts at 99 Hz)
            lf = np.log(fz)
            self.zi[u] = np.interp(np.log(f), lf, Z.real) + 1j * np.interp(np.log(f), lf, Z.imag)
        self.box = np.ones_like(f, dtype=complex)
        if box_ratio:
            self.set_box(None)

    def set_box(self, cfg):
        """cfg None or MAP None = plugged (as measured). Else dict(MAP=..., fill=...) for the vented box."""
        if cfg is None or cfg.get("MAP") is None:
            self.box = np.ones_like(self.f, dtype=complex); return
        sys.path.insert(0, str(PROJ / "ltspice" / "task1"))
        import box_model as bm
        drv, RAB, QL, QP, MAP, _ = FIT_CACHE.get("fit") or FIT_CACHE.setdefault("fit", bm.fit())
        closed = bm.system(self.f, drv, bm.box_dict(RAB=RAB))["p1m"]
        vented = bm.system(self.f, drv, bm.vent_box(RAB, QL, QP, cfg["MAP"], cfg.get("fill", 1.0)))["p1m"]
        self.box = vented / closed


FIT_CACHE = {}


# ---------------------------------------------------------------- digital (MiniDSP)
def bq(f0, Q, kind, fs=FS):
    """RBJ biquad, exactly BQ() in DigitalCrossover.m. Returns b0, b1, b2, a1, a2 (a0 = 1)."""
    w0 = 2 * math.pi * f0 / fs; al = math.sin(w0) / (2 * Q); a0 = 1 + al; c = math.cos(w0)
    if kind == "LPF":
        b0 = (1 - c) / 2 / a0; b1 = (1 - c) / a0
    else:
        b0 = (1 + c) / 2 / a0; b1 = -(1 + c) / a0
    return b0, b1, b0, -2 * c / a0, (1 - al) / a0


def sections(f0, kind, align):
    Qs = {"BW2": [1 / math.sqrt(2)], "LR4": [1 / math.sqrt(2)] * 2,
          "BW4": [1 / (2 * math.cos(math.pi / 8)), 1 / (2 * math.cos(3 * math.pi / 8))]}[align]
    return [bq(f0, Q, kind) for Q in Qs]


def h_digital(f, f0, kind, align):
    z1 = np.exp(-2j * np.pi * np.asarray(f) / FS)
    H = np.ones_like(z1)
    for b0, b1, b2, a1, a2 in sections(f0, kind, align):
        H = H * (b0 + b1 * z1 + b2 * z1 ** 2) / (1 + a1 * z1 + a2 * z1 ** 2)
    return H


def minidsp_text(f0, kind, align):
    """The biquad_DSP text DigitalCrossover.m prints (a1, a2 with the MiniDSP's sign)."""
    out = ""
    for k, (b0, b1, b2, a1, a2) in enumerate(sections(f0, kind, align), 1):
        out += (f"\n biquad{k}, \n b0 = {b0:.15f}, \n b1 = {b1:.15f}, \n b2 = {b2:.15f}, "
                f"\n a1 = {-a1:.15f}, \n a2 = {-a2:.15f}, ")
    return out


def g15(x):
    return f"{x:.15g}"


def ltspice_text(f0, kind, align):
    """One Laplace= string per section, the form DigitalCrossover.m writes."""
    T = g15(1 / FS)
    return [f"Laplace=({g15(b0)}+{g15(b1)}*exp(-s*{T})+{g15(b2)}*exp(-2*s*{T}))"
            f"/(1+{g15(a1)}*exp(-s*{T})+{g15(a2)}*exp(-2*s*{T}))" for b0, b1, b2, a1, a2 in sections(f0, kind, align)]


# ---------------------------------------------------------------- passive
def zel(kind, v, w):
    return {"L": 1j * w * v, "C": 1 / (1j * w * v), "R": v + 0j}[kind] * np.ones_like(w, dtype=complex)


def ladder(f, parts, Zload, Rdcr=0.0):
    """parts: list of (pos, kind, value), pos 'series' or 'shunt', in order from the amplifier to the
    driver. Inductors get Rdcr ohm per mH in series (0 = ideal). Returns V_driver / V_amp and the
    impedance the amplifier sees."""
    w = 2 * np.pi * np.asarray(f, float)
    A = np.ones_like(w, dtype=complex); B = np.zeros_like(A); C = np.zeros_like(A); D = np.ones_like(A)
    for pos, kind, v in parts:
        Z = zel(kind, v, w) + (Rdcr * v * 1e3 if kind == "L" else 0)
        if pos == "series":
            A, B, C, D = A, A * Z + B, C, C * Z + D
        else:
            Y = 1 / Z
            A, B, C, D = A + B * Y, B, C + D * Y, D
    T = Zload / (A * Zload + B)
    Zin = (A * Zload + B) / (C * Zload + D)
    return T, Zin


TOPOLOGIES = {
    # midrange low-pass
    "LP2": [("series", "L", "L1"), ("shunt", "C", "C1")],
    "LP1": [("series", "L", "L1")],
    # tweeter high-pass, with an L-pad (series Rs, shunt Rp right at the driver)
    "HP2": [("series", "C", "C1"), ("shunt", "L", "L1")],
    "HP3": [("series", "C", "C1"), ("shunt", "L", "L1"), ("series", "C", "C2")],
}


def passive_parts(topo, vals, pad=None, zobel=None):
    parts = [(p, k, vals[n]) for p, k, n in TOPOLOGIES[topo]]
    if pad:
        if pad.get("Rs"): parts.append(("series", "R", pad["Rs"]))
        if pad.get("Rp"): parts.append(("shunt", "R", pad["Rp"]))
    if zobel:
        parts.append(("shunt", "RC", zobel))
    return parts


def ladder2(f, parts, Zload, Rdcr):
    """ladder() plus a Zobel (series R + C) element kind 'RC' with value (R, C)."""
    w = 2 * np.pi * np.asarray(f, float)
    plain, extra = [], None
    for p in parts:
        if p[1] == "RC":
            extra = p[2]
        else:
            plain.append(p)
    if extra:
        Zz = extra[0] + 1 / (1j * w * extra[1])
        Zload = 1 / (1 / Zload + 1 / Zz)
    return ladder(f, plain, Zload, Rdcr)


# ---------------------------------------------------------------- the system
DEFAULT = {
    "box": {"MAP": 67.44, "fill": 1.0, "label": "one vent, L = 160 mm"},
    "digital": {"fc": 350.0, "align": "LR4", "g_woof_dB": -4.0},
    "mid": {"topo": "LP2", "vals": {"L1": 0.47e-3, "C1": 6.8e-6}, "zobel": None},
    "tw": {"topo": "HP3", "vals": {"C1": 6.8e-6, "L1": 0.33e-3, "C2": 10e-6}, "pad": {"Rs": 2.2, "Rp": 3.3}},
    "pol": {"woof": 1, "mid": 1, "tw": -1},
    "Rdcr": 0.0,
}


def evaluate(d, des, angle="on"):
    f = d.f
    HL = h_digital(f, des["digital"]["fc"], "LPF", des["digital"]["align"])
    HH = h_digital(f, des["digital"]["fc"], "HPF", des["digital"]["align"])
    gw = 10 ** (des["digital"]["g_woof_dB"] / 20)
    m, t = des["mid"], des["tw"]
    Tm, Zm = ladder2(f, passive_parts(m["topo"], m["vals"], zobel=m.get("zobel")), d.zi["mid"], des.get("Rdcr", 0))
    Tt, Zt = ladder2(f, passive_parts(t["topo"], t["vals"], pad=t.get("pad")), d.zi["tw"], des.get("Rdcr", 0))
    tf = d.tf[angle]
    out = {"woof": des["pol"]["woof"] * gw * HL * tf["woof"] * d.box,
           "mid": des["pol"]["mid"] * HH * Tm * tf["mid"],
           "tw": des["pol"]["tw"] * HH * Tt * tf["tw"]}
    out["sum"] = out["woof"] + out["mid"] + out["tw"]
    Zamp2 = 1 / (1 / Zm + 1 / Zt)                    # amplifier channel 2 sees mid || tweeter branch
    return out, dict(Tm=Tm, Tt=Tt, Zamp2=Zamp2, HL=HL, HH=HH)


def smooth(f, y_db, frac=6):
    """1/frac-octave smoothing on the log grid (for judging, not for display)."""
    lf = np.log2(f); out = np.empty_like(y_db)
    for i, x in enumerate(lf):
        k = np.abs(lf - x) <= 0.5 / frac
        out[i] = np.mean(y_db[k])
    return out


def crossings(d, out, lo, hi, a, b):
    """Acoustic crossover: where |a| and |b| (1/6-oct smoothed) cross inside [lo, hi], nearest the
    geometric centre. None if they never cross there."""
    k = np.where((d.f >= lo) & (d.f <= hi))[0]
    da = smooth(d.f, 20 * np.log10(np.abs(out[a]))) - smooth(d.f, 20 * np.log10(np.abs(out[b])))
    x = [i for i in k[:-1] if np.sign(da[i]) != np.sign(da[i + 1])]
    if not x:
        return None
    c = math.sqrt(lo * hi)
    i = min(x, key=lambda i: abs(math.log(d.f[i] / c)))
    return float(d.f[i])


LIMITS = {"wm": (250, 600), "mt": (2200, 4000)}   # woofer/mid and mid/tweeter acoustic crossover
TW_FS = 1450.0                                       # tweeter resonance (Lab D)


def penalty(d, des):
    """Engineering rules the flatness score alone does not know about."""
    out, _ = evaluate(d, des, "on")
    pen = 0.0
    for key, (a, b), (lo, hi) in (("wm", ("woof", "mid"), LIMITS["wm"]), ("mt", ("mid", "tw"), LIMITS["mt"])):
        fx = crossings(d, out, lo / 1.5, hi * 1.5, a, b)
        if fx is None:
            pen += 5
        else:
            pen += 3 * max(0.0, math.log2(lo / fx), math.log2(fx / hi))
    # the tweeter must be at least 12 dB below the system level at its resonance
    i = np.argmin(np.abs(d.f - TW_FS))
    k = (d.f >= 300) & (d.f <= 15000)
    ref = np.median(smooth(d.f, 20 * np.log10(np.abs(out["sum"])))[k])
    pen += 0.3 * max(0.0, 20 * np.log10(np.abs(out["tw"][i])) - (ref - 12))
    return pen


def score(d, des, lo=150, hi=15000):
    """Lower is better: RMS deviation of the smoothed on-axis sum from flat, plus half of the
    30 deg one, plus a penalty for the cancellation in the crossover regions (sum vs power sum)."""
    s = 0
    for ang, wgt in (("on", 1.0), ("off30", 0.5)):
        out, _ = evaluate(d, des, ang)
        k = (d.f >= lo) & (d.f <= hi)
        y = smooth(d.f, 20 * np.log10(np.abs(out["sum"])))[k]
        dev = y - np.median(y)
        pw = 10 * np.log10(sum(np.abs(out[u]) ** 2 for u in ("woof", "mid", "tw")))[k]
        canc = np.clip(pw - 20 * np.log10(np.abs(out["sum"]))[k], 0, None)
        s += wgt * (math.sqrt(np.mean(dev ** 2)) + 0.3 * math.sqrt(np.mean(canc ** 2)))
    return s + penalty(d, des)


# ---------------------------------------------------------------- search
def optimise(d, des, rounds=4, verbose=True):
    """Coordinate descent over the discrete choices. Every passive value stays in Appendix 1."""
    import copy
    des = copy.deepcopy(des)
    choices = []
    choices.append((("digital", "fc"), [float(x) for x in range(200, 701, 25)]))
    choices.append((("digital", "align"), ["BW2", "LR4", "BW4"]))
    choices.append((("digital", "g_woof_dB"), [x / 2 for x in range(-20, 5)]))
    for n in TOPOLOGIES[des["mid"]["topo"]]:
        choices.append((("mid", "vals", n[2]), L_STD if n[1] == "L" else C_STD))
    for n in TOPOLOGIES[des["tw"]["topo"]]:
        choices.append((("tw", "vals", n[2]), L_STD if n[1] == "L" else C_STD))
    choices.append((("tw", "pad", "Rs"), [0.0] + R_STD))
    choices.append((("tw", "pad", "Rp"), [None] + R_STD))
    choices.append((("pol", "tw"), [1, -1]))
    choices.append((("pol", "mid"), [1, -1]))

    def get(path):
        x = des
        for p in path: x = x[p]
        return x

    def put(path, v):
        x = des
        for p in path[:-1]: x = x[p]
        x[path[-1]] = v

    best = score(d, des)
    for r in range(rounds):
        changed = False
        for path, opts in choices:
            cur = get(path)
            for v in opts:
                put(path, v); s = score(d, des)
                if s < best - 1e-9:
                    best, cur, changed = s, v, True
            put(path, cur)
        if verbose:
            print(f"  round {r + 1}: score {best:.3f}")
        if not changed:
            break
    return des, best


# ---------------------------------------------------------------- reporting
def fmt(v, kind):
    return {"L": f"{v*1e3:.2f} mH", "C": f"{v*1e6:.1f} uF", "R": f"{v:g} ohm"}[kind]


def describe(des):
    dg = des["digital"]
    lines = [f"box: {des['box']['label']} (M_AP {des['box']['MAP']:.1f} kg/m^4)",
             f"digital: {dg['align']} at {dg['fc']:.0f} Hz, woofer gain {dg['g_woof_dB']:+.1f} dB"]
    for u, lab in (("mid", "midrange"), ("tw", "tweeter")):
        b = des[u]
        parts = ", ".join(f"{n} = {fmt(b['vals'][n], k)}" for _, k, n in TOPOLOGIES[b["topo"]])
        pad = b.get("pad") or {}
        pads = "".join(f", {k} = {v:g} ohm" for k, v in pad.items() if v)
        lines.append(f"{lab}: {b['topo']} {parts}{pads}")
    lines.append("polarity: " + ", ".join(f"{u} {'+' if p > 0 else '-'}" for u, p in des["pol"].items()))
    return "\n".join(lines)


def metrics(d, des):
    res = {}
    for ang in ("on", "off30"):
        out, aux = evaluate(d, des, ang)
        y = 20 * np.log10(np.abs(out["sum"])); k = (d.f >= 150) & (d.f <= 15000)
        ys = smooth(d.f, y)[k]
        res[ang] = dict(spread=float(ys.max() - ys.min()), rms=float(np.std(ys)), level=float(np.median(ys)))
    out, _ = evaluate(d, des, "on")
    res["x_wm"] = crossings(d, out, 150, 900, "woof", "mid")
    res["x_mt"] = crossings(d, out, 1400, 6000, "mid", "tw")
    zmin = float(np.min(np.abs(evaluate(d, des)[1]["Zamp2"])[(d.f > 200) & (d.f < 15000)]))
    res["Zamp2_min"] = zmin
    return res


def main():
    d = Data()
    p = HERE / "design.json"
    des = json.loads(p.read_text()) if p.exists() else DEFAULT
    d.set_box({"MAP": des["box"]["MAP"], "fill": des["box"].get("fill", 1.0)})
    if "--optimise" in sys.argv:
        import copy
        best = None
        for fc in (300.0, 400.0, 500.0):
            for topo in ("HP2", "HP3"):
                st = copy.deepcopy(DEFAULT); st["digital"]["fc"] = fc
                st["tw"]["topo"] = topo
                st["tw"]["vals"] = {"C1": 6.8e-6, "L1": 0.33e-3} | ({"C2": 10e-6} if topo == "HP3" else {})
                print(f"start fc {fc:.0f}, {topo}: score {score(d, st):.3f}")
                r, s = optimise(d, st, rounds=6, verbose=False)
                print(f"   -> {s:.3f}")
                if best is None or s < best[1]:
                    best = (r, s)
        des = best[0]
        p.write_text(json.dumps(des, indent=2))
        print("wrote", p.name)
    print(describe(des))
    m = metrics(d, des)
    for ang in ("on", "off30"):
        print(f"{ang:6s}: 150 Hz - 15 kHz (1/6 oct): spread {m[ang]['spread']:.1f} dB, std {m[ang]['rms']:.2f} dB, level {m[ang]['level']:.1f} dB re 1 Pa/V")
    print(f"acoustic crossovers: woofer/mid {m['x_wm'] or float('nan'):.0f} Hz, mid/tweeter {m['x_mt'] or float('nan'):.0f} Hz")
    print(f"amplifier ch. 2 load: |Z| min {m['Zamp2_min']:.2f} ohm (200 Hz - 15 kHz)")
    if "--plots" in sys.argv:
        import xover_plots
        xover_plots.main(d, des)
    if "--export" in sys.argv:
        export(d, des)


def export(d, des):
    out = PROJ / "data" / "dsp"; out.mkdir(exist_ok=True)
    dg = des["digital"]
    for kind, lab in (("LPF", "woofer_out1"), ("HPF", "midtw_out2")):
        (out / f"MiniDSP_{lab}.txt").write_text(minidsp_text(dg["fc"], kind, dg["align"]))
        (out / f"LTspice_{lab}.txt").write_text("\n\n".join(ltspice_text(dg["fc"], kind, dg["align"])) + "\n")
    print("wrote", out.relative_to(PROJ))
    m = metrics(d, des)
    mac = {"fcDig": f"{dg['fc']:.0f}", "alignDig": dg["align"], "gWoof": f"{dg['g_woof_dB']:+.1f}",
           "xWM": f"{m['x_wm']:.0f}", "xMT": f"{m['x_mt']:.0f}", "spreadOn": f"{m['on']['spread']:.1f}",
           "stdOn": f"{m['on']['rms']:.2f}", "spreadOff": f"{m['off30']['spread']:.1f}", "stdOff": f"{m['off30']['rms']:.2f}",
           "ZminAmp": f"{m['Zamp2_min']:.1f}"}
    for u, pre in (("mid", "Mid"), ("tw", "Tw")):
        b = des[u]
        mac[f"topo{pre}"] = b["topo"]
        for _, k, n in TOPOLOGIES[b["topo"]]:
            v = b["vals"][n]
            mac[f"{pre}{n.replace('1', 'a').replace('2', 'b')}"] = {"L": f"\\SI{{{v*1e3:g}}}{{mH}}", "C": f"\\SI{{{v*1e6:g}}}{{\\micro F}}"}[k]
    pad = des["tw"].get("pad") or {}
    mac["TwRs"] = f"\\SI{{{pad.get('Rs') or 0:g}}}{{\\ohm}}"; mac["TwRp"] = f"\\SI{{{pad.get('Rp') or 0:g}}}{{\\ohm}}"
    mac["polTw"] = "+" if des["pol"]["tw"] > 0 else "-"; mac["polMid"] = "+" if des["pol"]["mid"] > 0 else "-"
    w = 2 * np.pi
    mid, tw = des["mid"]["vals"], des["tw"]["vals"]
    mac["fMidLC"] = f"{1 / (w * math.sqrt(mid['L1'] * mid['C1'])):.0f}"
    mac["fTwLC"] = f"{1 / (w * math.sqrt(tw['L1'] * tw['C1'])):.0f}"
    if pad.get("Rs") and pad.get("Rp"):
        z = 4.0; zp = pad["Rp"] * z / (pad["Rp"] + z)
        mac["padDB"] = f"{20 * math.log10(zp / (pad['Rs'] + zp)):.1f}"
    tex = "% written by design/xover.py --export; do not edit\n" + "".join(
        f"\\newcommand{{\\x{k}}}{{{v}}}\n" for k, v in mac.items())
    (PROJ / "report" / "results_design.tex").write_text(tex)
    print("wrote report/results_design.tex")


if __name__ == "__main__":
    main()
