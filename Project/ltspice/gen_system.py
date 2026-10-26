#!/usr/bin/env python3
"""The complete System D design in LTspice, built from design/design.json.

    python3 gen_system.py            # write System_D_design.asc/.plt
    python3 gen_system.py --verify   # run LTspice at the Lab E frequencies, compare with design/xover.py

Same skeleton as System_template.asc (gen_templates.py), with:
  - the DigitalCrossover-style Laplace strings in the four E slots (LR4 = the same BW2 string twice),
  - the passive LPF / HPF + L-pad drawn in, Appendix 1 values only,
  - the woofer gain and the polarities as .params,
  - the Task 1 box tuning on the woofer as an extra Laplace-free table source (E_box, from the
    fitted box model) so the low end shows the vented box rather than the plugged one Lab E measured.
"""
import json, math, pathlib, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "design"))
import gen_templates as T                    # noqa: E402
import gen_ltspice as g                      # noqa: E402
import xover as X                            # noqa: E402

NAME = "System_D_design"


def val(kind, v):
    return {"L": f"{v*1e3:g}m", "C": f"{v*1e6:g}u", "R": f"{v:g}"}[kind]


def passive(s, x, y, parts, tag):
    """Draw series/shunt parts left to right on the rail at height y starting at x. Returns end x."""
    s.wire(x, y, x + 32, y); x += 32
    for i, (pos, kind, v) in enumerate(parts):
        name = f"{kind}{i + 1}_{tag}"
        if pos == "series":
            x = s.hser({"L": "ind", "C": "cap", "R": "res"}[kind], x, y, name, val(kind, v),
                       g.NOLOSS if kind == "L" else None, win=g.WIN_ABOVE)
            s.wire(x, y, x + 32, y); x += 32
        else:
            s.wire(x, y, x + 48, y); x += 48
            s.vshunt({"L": "ind", "C": "cap", "R": "res"}[kind], x, y, name, val(kind, v), g.NOLOSS if kind == "L" else None)
            s.wire(x, y, x + 48, y); x += 48
    return x


def box_table(d, des):
    """B(f) = p_vented / p_closed from the Task 1 model, written like Matlab2LTspice's files
    (a Bv source from lp2 to Vspkr_woof) into ../data/Box_woof.txt."""
    ph = np.degrees(np.unwrap(np.angle(d.box)))
    lines = [f"* Task 1 box tuning on the woofer: {des['box']['label']}, M_AP {des['box']['MAP']:.1f} kg/m^4 (gen_system.py)",
             "BvBox_woof Vspkr_woof 0  V=V(lp2,0) DB FREQ= "]
    lines += [f"+({f:.10E},{20*math.log10(abs(b)):.10E},{p:.10E})" for f, b, p in zip(d.f, d.box, ph)]
    (HERE.parent / "data" / "Box_woof.txt").write_text("\n".join(lines) + "\n")


def build(des, d):
    dg = des["digital"]
    LP = X.ltspice_text(dg["fc"], "LPF", dg["align"]); HP = X.ltspice_text(dg["fc"], "HPF", dg["align"])
    LP += ["1"] * (2 - len(LP)); HP += ["1"] * (2 - len(HP))
    a = T.Asc()
    a.t(-400, -400, f"System D design ({X.describe(des).splitlines()[1]}). Generated from design/design.json by gen_system.py; "
                    "edit the design there, not here.")
    a.t(-400, -368, "Digital E slots = DigitalCrossover.m form (MiniDSP at 96 kHz). Passive parts from Appendix 1 only. "
                    "V(Psum) = system on axis, V(Psum30) = 30 deg, for 1 V at the MiniDSP input.")
    a.l += ["SYMBOL voltage -400 -16 R0", "WINDOW 0 -56 40 Right 2", "WINDOW 3 -56 72 Right 2",
            "SYMATTR InstName V1", "SYMATTR Value 0", "SYMATTR Value2 AC 1"]
    a.flag(-400, 0, "Vin"); a.flag(-400, 80, "0")
    for row, (tag, out, strs, txt) in enumerate((("LP", "lp2", LP, "woofer: digital LPF (MiniDSP output 1)"),
                                                 ("HP", "Vhp", HP, "mid + tweeter: digital HPF (MiniDSP output 2)"))):
        y = row * 320
        a.t(-80, y - 96, txt)
        a.e(0, y, f"E_{tag}1", strs[0], "Vin", hide=True); a.w(0, y, 112, y); a.flag(112, y, f"{tag.lower()}1")
        a.e(256, y, f"E_{tag}2", strs[1], f"{tag.lower()}1", hide=True); a.w(256, y, 400, y); a.flag(400, y, out)
        a.t(-80, y + 176, f"{dg['align']} {'low' if tag == 'LP' else 'high'}-pass at {dg['fc']:g} Hz: one biquad per E source (Value hidden; Ctrl+right-click to see it)")
    box_table(d, des)
    a.t(560, -16, "lp2 -> Vspkr_woof: Task 1 box tuning, vented / plugged (fitted model), in ../data/Box_woof.txt")
    # passive branches, drawn with the Lab A builder and merged into the same sheet
    s = g.Sch()
    for row, (u, kind) in enumerate((("mid", "LPF"), ("tw", "HPF"))):
        y = 768 + row * 384
        b = des[u]
        parts = [p for p in X.passive_parts(b["topo"], b["vals"], pad=b.get("pad"))]
        s.flag(0, y, "Vhp")
        x = passive(s, 0, y, parts, u)
        s.wire(x, y, x + 64, y)
        a.l += [f"RECTANGLE Normal 16 {y - 144} {x + 16} {y + 176} 2"]
        a.t(32, y - 128, f"passive {kind} ({X.describe(des).splitlines()[2 + row].split(':')[1].strip()})")
        xe = a.yi(x + 144, y, f"Yi_{u}"); s.wire(x + 64, y, x + 144, y); s.wire(xe, y, xe + 96, y); s.flag(xe + 96, y, f"Vspkr_{u}")
    a.l += s.wires + s.flags + s.syms + s.texts
    for k, (sfx, lab) in enumerate((("", "on axis"), ("30", "30 deg"))):
        x = 1840 + k * 640
        a.t(x - 160, -96, f"sum, {lab}")
        nodes = ["0", f"s{sfx}1", f"s{sfx}2", f"Psum{sfx}"]
        for j, u in enumerate(("woof", "mid", "tw")):
            y = 160 + j * 256
            a.e(x, y, f"E_S{sfx}{u}", f"{{g_{u}*p_{u}}}", f"Pout{sfx}_{u}", oneg=nodes[j])
            a.w(x, y, x + 112, y); a.flag(x + 112, y, nodes[j + 1])
    gw = 10 ** (dg["g_woof_dB"] / 20)
    a.t(1680, 1100, f".param g_woof={gw:.6g} g_mid=1 g_tw=1   p_woof={des['pol']['woof']} p_mid={des['pol']['mid']} p_tw={des['pol']['tw']}", d=True)
    a.t(1680, 1140, f"g_woof = {dg['g_woof_dB']:+.1f} dB = the MiniDSP output 1 gain; p_ = polarity of each unit")
    y = 1300
    for i, f in enumerate(["TF_woof", "TF30_woof", "Zi_mid", "TF_mid", "TF30_mid", "Zi_tw", "TF_tw", "TF30_tw", "Box_woof"]):
        a.t(-400 + (i % 5) * 400, y + (i // 5) * 40, f".inc ../data/{f}.txt", d=True)
    a.t(-400, y + 120, ".ac dec 200 20 20000", d=True)
    p = HERE / f"{NAME}.asc"
    a.dump(p)
    g.plt(p.with_suffix(".plt"), [(["V(Psum)", "V(Psum30)"], (0.05, 5)), (["V(Pout_woof)", "V(Pout_mid)", "V(Pout_tw)", "V(Psum)"], (1e-3, 5)),
                                  (["V(Vhp)/(I(Yi_mid)+I(Yi_tw))"], (1, 100))], (20, 20000))
    return p


def verify(p, des, d):
    """Run at exactly the Lab E frequencies (no table interpolation for TF), compare with xover.py."""
    txt = p.read_text()
    freqs = " ".join(f"{f:g}" for f in d.f)
    q = p.with_name(NAME + "_verify.asc")
    q.write_text(txt.replace("!.ac dec 200 20 20000", f"!.ac list {freqs}"))
    r = T.run(q); q.unlink()
    ok = True
    for ang, sfx in (("on", ""), ("off30", "30")):
        out, aux = X.evaluate(d, des, ang)
        got = r[f"v(psum{sfx})"]
        k = (d.f >= 100) & (d.f <= 18000)
        e_db = np.abs(20 * np.log10(np.abs(got[k]) / np.abs(out["sum"][k])))
        tau = 2 * np.pi * d.f[k] * X_D / 345
        e_ph = np.degrees(np.abs(np.angle(got[k] / (out["sum"][k] * np.exp(1j * tau)))))
        good = np.median(e_db) < 0.05 and np.percentile(e_db, 95) < 0.3
        ok &= good
        print(f"  {'OK ' if good else 'BAD'} V(Psum{sfx}) vs xover.py, 100 Hz-18 kHz: median {np.median(e_db):.3f} dB, "
              f"95 % {np.percentile(e_db, 95):.3f} dB, worst {e_db.max():.2f} dB; phase median {np.median(e_ph):.2f} deg")
    print("ALL OK" if ok else "MISMATCH")
    return ok


X_D = -1.15                                      # distance the TF files carry (export_systemD.m)

if __name__ == "__main__":
    des = json.loads((HERE.parent / "design" / "design.json").read_text())
    d = X.Data(); d.set_box({"MAP": des["box"]["MAP"], "fill": des["box"].get("fill", 1.0)})
    p = build(des, d)
    print("wrote", p.name)
    if "--verify" in sys.argv:
        sys.exit(0 if verify(p, des, d) else 1)
