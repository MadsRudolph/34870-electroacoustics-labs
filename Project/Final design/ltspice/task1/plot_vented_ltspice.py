#!/usr/bin/env python3
"""Task 1 result straight from LTspice: Woofer_Vented_L160.asc (and its plugged twin as the
closed-box reference), far field, near field and impedance against Lab D.

    python3 plot_vented_ltspice.py    # runs LTspice under wine, writes ../../figures/task1_ltspice_vented.png
"""
import pathlib, sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[3] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402
import box_model as bm                       # noqa: E402
import gen_vented_course as gv               # noqa: E402

C = {"cone": "#1f77b4", "vent": "#d62728", "tot": "k", "ref": "0.5"}


def run(path):
    d = g.run_ltspice(path)
    return {k: np.array(v) for k, v in d.items() if not k.startswith("_")}


def db(x):
    return 20 * np.log10(np.abs(x))


def f3(f, spl):
    ref = np.mean(spl[(f >= 150) & (f <= 300)])
    k = np.where(spl >= ref - 3)[0][0]
    return f[k], np.max(spl[(f >= 10) & (f <= 300)]) - ref


if __name__ == "__main__":
    drv, box, MA1 = gv.values()
    v = run(gv.build(drv, box, MA1))
    c = run(gv.build(drv, box, MA1, plugged=True))
    f = v["frequency"].real
    pD, pP, pT = v["v(db_spl_diaph)"], v["v(db_spl_vent)"], v["v(db_spl_total)"]
    # sign of the vent source: Vd3 counts U_P into the box, so the radiated vent pressure is -p
    s = -1 if np.median(np.abs((pD - pP) / pT - 1)) < np.median(np.abs((pD + pP) / pT - 1)) else 1
    pP = s * pP
    fb = bm.fb_of(box["MAP"])
    f3v, ripv = f3(f, db(pT)); f3c, ripc = f3(f, db(c["v(db_spl_total)"]))
    print(f"LTspice: vented f_3 {f3v:.1f} Hz, ripple {ripv:+.2f} dB;  closed f_3 {f3c:.1f} Hz, ripple {ripc:+.2f} dB;  f_B {fb:.1f} Hz")

    fig, ax = plt.subplots(2, 2, figsize=(12, 7), sharex="col")
    for p, lab, col, ls, lw in ((pD, "driver (cone)", C["cone"], "-", 1.4), (pP, "vent", C["vent"], "-", 1.4),
                                (pT, "total", C["tot"], "-", 2.2),
                                (c["v(db_spl_total)"], "closed box (vents plugged)", C["ref"], "--", 1.3)):
        ax[0, 0].semilogx(f, db(p), color=col, ls=ls, lw=lw, label=lab)
        ax[1, 0].semilogx(f, np.degrees(np.angle(p)), color=col, ls=ls, lw=lw)
    ax[0, 0].axvline(fb, color="0.6", ls=":")
    ax[0, 0].text(fb * 1.03, 51.5, f"f_B = {fb:.1f} Hz", fontsize=8, color="0.35")
    ax[0, 0].axvline(f3v, color="k", ls=":", lw=0.8)
    ax[0, 0].text(f3v * 1.03, 55, f"f_3 = {f3v:.0f} Hz", fontsize=8)
    ax[0, 0].set_ylim(50, 95); ax[0, 0].set_ylabel("SPL at 1 m for 1 V (dB re 20 µPa)")
    ax[0, 0].set_title("Far field (LTspice), one vent L = 160 mm, half space", fontsize=10)
    ax[0, 0].legend(fontsize=8, loc="lower right")
    ax[1, 0].set_ylim(-190, 190); ax[1, 0].set_yticks(range(-180, 181, 90)); ax[1, 0].set_ylabel("Phase (deg)")
    ax[1, 0].set_xlim(10, 500); ax[1, 0].set_xlabel("Frequency (Hz)")

    for name, node, col in (("cone", "v(nf_cone)", C["cone"]), ("vent", "v(nf_vent)", C["vent"])):
        fm, pm = bm.load(f"NF_{name}_L160")
        k = (fm >= 8) & (fm <= 500)
        ax[0, 1].semilogx(fm[k], db(pm[k]), color=col, lw=1, alpha=0.55, label=f"{name} measured (Lab D)")
        ax[0, 1].semilogx(f, db(v[node]), color=col, lw=1.8, ls="--", label=f"{name} LTspice")
    ax[0, 1].set_ylim(-30, 25); ax[0, 1].set_ylabel("|p/V| near field (dB re 1 Pa/V)")
    ax[0, 1].set_title("Near field: Lab D measurement vs LTspice, L = 160 mm", fontsize=10)
    ax[0, 1].legend(fontsize=8, loc="lower left", ncol=2)
    fz, zm = bm.load("Z_vent_L160")
    k = (fz >= 8) & (fz <= 500)
    ax[1, 1].semilogx(fz[k], np.abs(zm[k]), color="0.3", lw=1, alpha=0.7, label="measured (Lab D)")
    ax[1, 1].semilogx(f, np.abs(v["v(eg)"] / v["i(vd1)"]), "k--", lw=1.8, label="LTspice")
    ax[1, 1].set_ylim(0, 60); ax[1, 1].set_ylabel("|Z_E| (ohm), vented L = 160 mm")
    ax[1, 1].legend(fontsize=8, loc="upper right")
    ax[1, 1].set_xlim(10, 500); ax[1, 1].set_xlabel("Frequency (Hz)")
    for a in ax.ravel():
        a.grid(True, which="both", alpha=0.3)
    fig.tight_layout()
    out = HERE.parents[1] / "figures" / "task1_ltspice_vented.png"
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out.name)
