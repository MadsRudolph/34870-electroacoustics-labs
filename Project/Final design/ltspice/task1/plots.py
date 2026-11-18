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


def finish(fig, axes, name, xlim=(5, 300), rect=None):
    for a in axes:
        a.grid(True, which="both", alpha=0.3); a.set_xlim(*xlim)
    axes[-1].set_xlabel("Frequency (Hz)")
    fig.tight_layout(rect=rect); bm.FIG.mkdir(exist_ok=True)
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
    farfield(drv, RAB, QL, QP, MAP)


def contributions(f, r):
    """Complex far-field pressure (Pa/V, 1 m, half space) of the cone and of the vent.

    box_model.system gives p_1m = j w rho (U_D - U_P) / (2 pi r), so the cone term is
    +j w rho U_D / (2 pi) and the vent term -j w rho U_P / (2 pi); cone + vent = p_1m exactly.
    """
    k = 1j * f * bm.RHO                       # j w rho / (2 pi), r = 1 m
    return k * r["UD"], -k * r["UP"]


def measured_farfield(tag):
    """Far field (Pa/V, 1 m, half space) of cone and vent rebuilt from the measured near fields.

    p_nf = j w rho U / (pi a)  and  p_1m = j w rho U / (2 pi r)  ->  p_1m = p_nf * a / (2 r), r = 1 m.
    Cone: +p_nf_cone * a_D / 2.  Vent: -p_nf_vent * a_P / 2 (far field goes with U_D - U_P).
    Same assumptions as the model: ka << 1, baffled pistons, half space.
    Returns f, p_cone, p_vent (complex); the vent is interpolated onto the cone frequency grid.
    """
    fc, Hc = bm.band(*bm.load(f"NF_cone_{tag}"), 8, 300)
    fv, Hv = bm.band(*bm.load(f"NF_vent_{tag}"), 8, 300)
    Hv = np.interp(fc, fv, Hv.real) + 1j * np.interp(fc, fv, Hv.imag)
    return fc, Hc * bm.AD / 2, -Hv * bm.AP / 2


def farfield(drv, RAB, QL, QP, MAP, Vg=2.83):
    """Far field at 1 m (half space): driver, vent and total per vent length.
    Model (dashed / thick) against the far field rebuilt from the measured near fields (thin)."""
    from matplotlib.lines import Line2D
    f = np.geomspace(10, 400, 1500)
    spl = lambda p: db(Vg * p / 20e-6)
    ref = bm.system(f, drv, bm.box_dict(RAB=RAB))["p1m"]
    fig, axs = plt.subplots(3, 1, figsize=(8, 10), sharex=True)
    for ax, L in zip(axs, bm.LENGTHS):
        bx = bm.vent_box(RAB, QL, QP, MAP[L])
        r = bm.system(f, drv, bx)
        p_cone, p_vent = contributions(f, r)
        fb = bm.fb_of(bx["MAP"])
        f3, rip, _ = bm.f3_and_ripple(f, r["p1m"])
        fm, pc_m, pv_m = measured_farfield(f"L{int(L*1e3)}")
        ax.semilogx(f, spl(ref), color="0.65", lw=1.3)
        ax.semilogx(fm, spl(pc_m), color=COL[0], lw=1, alpha=0.6)
        ax.semilogx(fm, spl(pv_m), color=COL[1], lw=1, alpha=0.6)
        ax.semilogx(fm, spl(pc_m + pv_m), color="k", lw=1, alpha=0.6)
        ax.semilogx(f, spl(p_cone), color=COL[0], ls="--", lw=1.6)
        ax.semilogx(f, spl(p_vent), color=COL[1], ls="--", lw=1.6)
        ax.semilogx(f, spl(r["p1m"]), color="k", ls="--", lw=2.0)
        ax.axvline(fb, color="k", ls=":", lw=1)
        ax.text(fb * 1.04, 0.03, f"f_B = {fb:.1f} Hz", fontsize=8, va="bottom", transform=ax.get_xaxis_transform())
        ax.set_ylim(40, 100); ax.set_ylabel(f"SPL at 1 m, {Vg} V (dB)")
        ax.set_title(f"Vent L = {L*1e3:.0f} mm: model f3 = {f3:.0f} Hz, ripple {rip:+.1f} dB", fontsize=10)
    h = [Line2D([], [], color=COL[0], lw=2), Line2D([], [], color=COL[1], lw=2),
         Line2D([], [], color="k", lw=2), Line2D([], [], color="0.65", lw=1.5),
         Line2D([], [], color="0.3", lw=1, alpha=0.7), Line2D([], [], color="0.3", lw=1.8, ls="--")]
    fig.legend(h, ["driver (cone)", "vent", "total (cone + vent)", "closed box (model)",
                   "from measured near field", "model"], loc="lower center", ncol=3, fontsize=8, frameon=False)
    finish(fig, axs, "task1_farfield.png", xlim=(10, 300), rect=(0, 0.05, 1, 1))


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