#!/usr/bin/env python3
"""Builds Crossover Studio (index.html) from app.src.html + engine.js + the measured data.

    python3 build_app.py           # write data.json, reference.json and index.html
    python3 build_app.py --test    # also run test_engine.mjs (Node): the JS engine against xover.py

data.json       the Lab D/E data on the Lab E grid, the fitted box model and the current design.json
reference.json  xover.py's own result for design.json (the sum on and off axis, the crossovers),
                so the JS port can be checked number for number.
index.html      a single self-contained page (data and engine inlined), published as the artifact.
"""
import json, math, pathlib, subprocess, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
sys.path.insert(0, str(PROJ / "design"))
sys.path.insert(0, str(PROJ / "ltspice" / "task1"))
import xover as X                          # noqa: E402
import box_model as bm                     # noqa: E402


def cplx(z, sig=6):
    z = np.asarray(z)
    return [float(f"{v:.{sig}g}") for v in z.real], [float(f"{v:.{sig}g}") for v in z.imag]


def main():
    d = X.Data()
    des = json.loads((PROJ / "design" / "design.json").read_text())
    drv, RAB, QL, QP, MAP, _ = bm.fit()
    data = {
        "f": [float(x) for x in d.f],
        "tf": {a: {u: cplx(d.tf[a][u]) for u in ("woof", "mid", "tw")} for a in ("on", "off30")},
        "zi": {u: cplx(d.zi[u]) for u in ("mid", "tw")},
        "box": {"T": bm.T, "c": bm.C0, "rho": bm.RHO, "RE": bm.RE, "SD": bm.SD, "AD": bm.AD, "VB": bm.VB, "AP": bm.AP,
                "drv": drv, "RAB": RAB, "QL": QL, "QP": QP,
                "MAP": [[L, m] for L, m in MAP.items()]},
        "labD": {},
        "std": {"L": X.L_STD, "C": X.C_STD, "R": X.R_STD},
        "design": des,
        "limits": X.LIMITS, "twFs": X.TW_FS,
    }
    for name in ("woofer_free", "woofer_closed", "vent_L160", "vent_L200", "vent_L240"):
        f, Z = bm.load(f"Z_{name}"); k = (f >= 5) & (f <= 300)
        data["labD"]["Z_" + name] = [list(map(float, f[k])), *cplx(Z[k], 5)]
    for L in ("L160", "L200", "L240"):
        for part in ("cone", "vent"):
            f, H = bm.load(f"NF_{part}_{L}"); k = (f >= 8) & (f <= 300)
            data["labD"][f"NF_{part}_{L}"] = [list(map(float, f[k])), *cplx(H[k], 5)]
    (HERE / "data.json").write_text(json.dumps(data, separators=(",", ":")))

    # reference from the Python engine
    d.set_box({"MAP": des["box"]["MAP"], "fill": des["box"].get("fill", 1.0)})
    ref = {"score": X.score(d, des), "metrics": X.metrics(d, des)}
    for a in ("on", "off30"):
        out, aux = X.evaluate(d, des, a)
        ref[a] = {k: cplx(v, 10) for k, v in out.items()}
    ref["Zamp2"] = cplx(X.evaluate(d, des)[1]["Zamp2"], 10)
    ref["box"] = cplx(d.box, 10)
    ref["minidsp"] = {k: X.minidsp_text(des["digital"]["fc"], k, des["digital"]["align"]) for k in ("LPF", "HPF")}
    ref["ltspice"] = {k: X.ltspice_text(des["digital"]["fc"], k, des["digital"]["align"]) for k in ("LPF", "HPF")}
    (HERE / "reference.json").write_text(json.dumps(ref))

    src = (HERE / "app.src.html").read_text()
    eng = (HERE / "engine.js").read_text().replace("export ", "")
    page = src.replace("/*@@ENGINE@@*/", eng).replace("/*@@DATA@@*/null", json.dumps(data, separators=(",", ":")))
    (HERE / "index.html").write_text(page)
    print(f"wrote index.html ({len(page)/1024:.0f} kB), data.json, reference.json")
    if "--test" in sys.argv:
        r = subprocess.run(["node", str(HERE / "test_engine.mjs")], cwd=HERE)
        sys.exit(r.returncode)


if __name__ == "__main__":
    main()
