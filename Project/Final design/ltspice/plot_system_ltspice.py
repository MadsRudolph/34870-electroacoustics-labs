#!/usr/bin/env python3
"""Task 2 result straight from LTspice: System_D_course.asc, each unit's V(Pout) (woofer x its gain),
V(Psum) on axis and V(Psum30), magnitude and phase (d = -1.15 m, as in the data files).

    python3 plot_system_ltspice.py    # runs LTspice under wine, writes ../figures/system_ltspice.png
"""
import json, pathlib
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

import gen_templates as T
import gen_system_course as G

HERE = pathlib.Path(__file__).resolve().parent
COL = {"woof": "#1f77b4", "mid": "#ff7f0e", "tw": "#2ca02c"}
LAB = {"woof": "woofer: digital LR4 low-pass, -4.5 dB", "mid": "midrange: digital LR4 high-pass + LP2",
       "tw": "tweeter: digital LR4 high-pass + HP2 + L-pad"}


def smooth(f, p, frac=6):
    """1/frac-octave power smoothing on any frequency grid."""
    pw = np.abs(p) ** 2
    return np.array([10 * np.log10(pw[np.abs(np.log2(f / x)) <= 0.5 / frac].mean()) for x in f])


if __name__ == "__main__":
    des = json.loads((HERE.parent / "design" / "design.json").read_text())
    r = T.run(G.build(des))
    f = r["frequency"].real
    g = 10 ** (des["digital"]["g_woof_dB"] / 20)
    P = {"woof": g * r["v(pout_woof)"], "mid": r["v(pout_mid)"], "tw": r["v(pout_tw)"]}
    S, S30 = r["v(psum)"], r["v(psum30)"]
    k = (f >= 150) & (f <= 15000)
    sm, sm30 = smooth(f, S), smooth(f, S30)
    spread, spread30 = np.ptp(sm[k]), np.ptp(sm30[k])
    lvl = (sm[k].max() + sm[k].min()) / 2
    print(f"LTspice: spread 150 Hz-15 kHz (1/6 oct) on axis {spread:.1f} dB, 30 deg {spread30:.1f} dB")

    fig, (a1, a2) = plt.subplots(2, 1, figsize=(10, 7.5), sharex=True, gridspec_kw={"height_ratios": [3, 2]})
    for u in ("woof", "mid", "tw"):
        a1.semilogx(f, 20 * np.log10(np.abs(P[u])), color=COL[u], lw=1.2, label=LAB[u])
        ph = np.degrees(np.angle(P[u]))
        ph[np.abs(P[u]) < np.abs(S) * 10 ** (-15 / 20)] = np.nan       # phase only where the unit plays
        a2.semilogx(f, ph, color=COL[u], lw=1.1)
    a1.semilogx(f, 20 * np.log10(np.abs(S)), "k", lw=2, label="V(Psum), on axis")
    a1.semilogx(f, sm30, color="0.45", lw=1.3, ls="--", label="V(Psum30), 30 deg, 1/6 oct")
    a2.semilogx(f, np.degrees(np.angle(S)), "k", lw=1.8)
    a1.axhspan(lvl - 2, lvl + 2, color="0.88", zorder=0, label="±2 dB")
    a1.axvspan(f[0], 125, color="0.93", zorder=0)
    a1.text(52, lvl - 27, "below 125 Hz:\nanechoic data\nnot valid", fontsize=8, color="0.4")
    for x in (325, 3762):
        for a in (a1, a2):
            a.axvline(x, color="0.55", ls=":")
    a1.text(325 * 1.04, lvl + 5.5, "325 Hz", fontsize=8, color="0.35")
    a1.text(3762 * 1.04, lvl + 5.5, "3.76 kHz", fontsize=8, color="0.35")
    a1.set_ylim(lvl - 30, lvl + 8); a1.set_ylabel("|p/V| at the mic, 2.44 m (dB re 1 Pa/V)")
    a1.set_title(f"System_D_course.asc in LTspice: on-axis spread {spread:.1f} dB, 30 deg {spread30:.1f} dB "
                 "(150 Hz-15 kHz, 1/6 octave)", fontsize=10)
    a1.legend(fontsize=8, loc="lower center", ncol=2)
    a2.set_ylim(-190, 190); a2.set_yticks(range(-180, 181, 90)); a2.set_ylabel("Phase, d = -1.15 m (deg)")
    a2.set_title("Phase of each unit where it is within 15 dB of the sum", fontsize=9)
    a2.set_xlim(50, 20000); a2.set_xlabel("Frequency (Hz)")
    for a in (a1, a2):
        a.grid(True, which="both", alpha=0.3)
    fig.tight_layout()
    out = HERE.parent / "figures" / "system_ltspice.png"
    fig.savefig(out, dpi=150); plt.close(fig)
    print("wrote", out.name)
