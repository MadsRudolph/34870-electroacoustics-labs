"""Figures for Task 1 (called by box_model.py --plots)."""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import box_model as bm

COL = ["#1f77b4", "#d62728", "#2ca02c"]


def db(x):
    return 20 * np.log10(np.abs(x))


def zplot(ax_m, ax_p, f, Zm, Zs, c, lab):
    ax_m.semilogx(f, np.abs(Zm), color=c, lw=1, alpha=0.5)
    ax_m.semilogx(f, np.abs(Zs), color=c, lw=1.6, ls="--", label=lab)
    ax_p.semilogx(f, np.degrees(np.angle(Zm)), color=c, lw=1, alpha=0.5)
    ax_p.semilogx(f, np.degrees(np.angle(Zs)), color=c, lw=1.6, ls="--")


def finish(fig, axes, name, xlim=(5, 300)):
    for a in axes:
        a.grid(True, which="both", alpha=0.3); a.set_xlim(*xlim)
    axes[-1].set_xlabel("Frequency (Hz)")
    fig.tight_layout(); bm.FIG.mkdir(exist_ok=True)
    fig.savefig(bm.FIG / name, dpi=150); plt.close(fig)
    print("wrote", bm.FIG / name)


def main(drv, RAB, QL, QP, MAP):
    # ---- impedance: free, closed and the three vent lengths, measured (thin) vs model (dashed)
    fig, (am, ap) = plt.subplots(2, 1, figsize=(8, 6.5), sharex=True)
    for name, bx, c in (("woofer_free", None, "k"), ("woofer_closed", bm.box_dict(RAB=RAB), "C4")):
        f, Z = bm.band(*bm.load("Z_" + name), 5, 300)
        zplot(am, ap, f, Z, bm.system(f, drv, bx)["ZE"], c, name.replace("woofer_", "") + " (model dashed)")
    for L, c in zip(bm.LENGTHS, COL):
        f, Z = bm.band(*bm.load(f"Z_vent_L{int(L*1e3)}"), 5, 300)
        bx = bm.vent_box(RAB, QL, QP, MAP[L])
        zplot(am, ap, f, Z, bm.system(f, drv, bx)["ZE"], c, f"1 vent, L = {L*1e3:.0f} mm")
    am.set_ylabel("|Z_E| (ohm)"); ap.set_ylabel("Phase (deg)"); am.legend(fontsize=8)
    am.set_title("Woofer input impedance: Lab D measured (solid) vs fitted model (dashed)")
    finish(fig, (am, ap), "task1_impedance_fit.png")

    # ---- near field, absolute Pa/V: predicted from the impedance fit, not fitted to it
    fig, axs = plt.subplots(3, 1, figsize=(8, 9), sharex=True)
    for ax, L in zip(axs, bm.LENGTHS):
        tag = f"L{int(L*1e3)}"
        bx = bm.vent_box(RAB, QL, QP, MAP[L])
        for part, c in (("cone", COL[0]), ("vent", COL[1])):
            f, H = bm.band(*bm.load(f"NF_{part}_{tag}"), 8, 300)
            r = bm.system(f, drv, bx)
            ax.semilogx(f, db(H), color=c, lw=1, alpha=0.6, label=f"{part} measured")
            ax.semilogx(f, db(r["nf_" + part]), color=c, lw=1.6, ls="--", label=f"{part} model")
        ax.set_ylabel("|p/V| (dB re 1 Pa/V)"); ax.set_ylim(-30, 25)
        ax.set_title(f"Near field, vent L = {L*1e3:.0f} mm (f_B model {bm.fb_of(bx['MAP']):.1f} Hz)", fontsize=10)
        ax.legend(fontsize=8, ncol=4)
    finish(fig, axs, "task1_nearfield.png")
    tuning(drv, RAB, QL, QP, MAP)


def tuning(drv, RAB, QL, QP, MAP, Vg=2.83):
    """The options side by side: far-field response (1 m, half space) and cone excursion at Vg."""
    f = np.geomspace(10, 400, 1500)
    rows = [("closed (vents plugged)", bm.box_dict(RAB=RAB), "k", "-")]
    rows += [(f"1 vent, L = {L*1e3:.0f} mm", bm.vent_box(RAB, QL, QP, m), c, "-") for (L, m), c in zip(MAP.items(), COL)]
    rows += [("M_AP 52 (f_B 28 Hz, e.g. two vents)", bm.vent_box(RAB, QL, QP, 52.0), "C4", "--"),
             ("1 vent L = 160, filling (V x 1.15)", bm.vent_box(RAB, QL, QP, MAP[0.160], 1.15), COL[0], ":")]
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(8, 7), sharex=True)
    for lab, bx, c, ls in rows:
        r = bm.system(f, drv, bx)
        f3, rip, ref = bm.f3_and_ripple(f, r["p1m"])
        a1.semilogx(f, db(Vg * r["p1m"] / 20e-6), color=c, ls=ls, lw=1.6, label=f"{lab}: f3 {f3:.0f} Hz, ripple {rip:+.1f} dB")
        x = np.abs(Vg * r["UD"] / bm.SD / (2j * np.pi * f)) * 1e3
        a2.semilogx(f, x, color=c, ls=ls, lw=1.6)
    a1.set_ylabel(f"SPL at 1 m, {Vg} V (dB)"); a1.set_ylim(60, 100); a1.legend(fontsize=7.5, loc="lower right")
    a1.set_title("Woofer box options (fitted model, half space, no room)", fontsize=10)
    a2.set_ylabel(f"cone excursion at {Vg} V (mm peak)"); a2.set_ylim(0, 2)
    finish(fig, (a1, a2), "task1_tuning.png", xlim=(10, 400))
