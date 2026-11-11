#!/usr/bin/env python3
"""Builds Auralis — Virtual Listening Room & Crossover Auralizer (Project/auralizer/index.html).

    python3 build_auralizer.py           # write data.json, reference.json, and index.html
    python3 build_auralizer.py --test    # also run test_auralizer.mjs (Node) to verify DSP & physics

Reads measurement data from Project/data/csv/ and Project/design/design.json (read-only).
Does not touch Project/app/ or any other files outside Project/auralizer/.
"""
import json, pathlib, subprocess, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
PROJ = HERE.parent
sys.path.insert(0, str(PROJ / "design"))
sys.path.insert(0, str(PROJ / "ltspice" / "task1"))
import xover as X          # noqa: E402
import box_model as bm     # noqa: E402


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
        "box": {
            "T": bm.T, "c": bm.C0, "rho": bm.RHO, "RE": bm.RE,
            "SD": bm.SD, "AD": bm.AD, "VB": bm.VB, "AP": bm.AP,
            "drv": drv, "RAB": RAB, "QL": QL, "QP": QP,
            "MAP": [[L, m] for L, m in MAP.items()],
        },
        "std": {"L": X.L_STD, "C": X.C_STD, "R": X.R_STD},
        "design": des,
        "limits": X.LIMITS,
        "twFs": X.TW_FS,
    }
    (HERE / "data.json").write_text(json.dumps(data, separators=(",", ":")))

    # Reference evaluation from xover.py for automated verification
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

    src_path = HERE / "auralizer.src.html"
    if src_path.exists():
        src = src_path.read_text()
        eng = (HERE / "auralizer.js").read_text().replace("export ", "")
        page = src.replace("/*@@ENGINE@@*/", eng).replace("/*@@DATA@@*/null", json.dumps(data, separators=(",", ":")))
        (HERE / "index.html").write_text(page)
        print(f"wrote index.html ({len(page)/1024:.0f} kB), data.json, reference.json")
    else:
        print("wrote data.json, reference.json (auralizer.src.html not yet created)")

    if "--test" in sys.argv:
        r = subprocess.run(["node", str(HERE / "test_auralizer.mjs")], cwd=HERE)
        sys.exit(r.returncode)


if __name__ == "__main__":
    main()
