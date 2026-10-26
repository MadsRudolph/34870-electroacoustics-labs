"""Figures for the crossover design (called by xover.py --plots)."""
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import xover as X

FIG = X.PROJ / "figures"
COL = {"woof": "#1f77b4", "mid": "#ff7f0e", "tw": "#2ca02c", "sum": "k"}
LAB = {"woof": "woofer", "mid": "midrange", "tw": "tweeter", "sum": "sum"}


def db(x):
    return 20 * np.log10(np.abs(x))


def save(fig, name):
    fig.tight_layout(); FIG.mkdir(exist_ok=True)
    fig.savefig(FIG / name, dpi=150); plt.close(fig)
    print("wrote", FIG / name)


def main(d, des):
    f = d.f
    m = X.metrics(d, des)
    # ---- system response on and off axis, with the three contributions
    fig, axs = plt.subplots(2, 1, figsize=(9, 8), sharex=True)
    for ax, ang, title in ((axs[0], "on", "on axis"), (axs[1], "off30", "30 deg")):
        out, _ = X.evaluate(d, des, ang)
        for u in ("woof", "mid", "tw"):
            ax.semilogx(f, db(out[u]), color=COL[u], lw=1.2, label=LAB[u])
        ax.semilogx(f, db(out["sum"]), "k", lw=2, label="sum")
        lvl = m[ang]["level"]
        ax.axhspan(lvl - 2, lvl + 2, color="0.85", zorder=0, label="+/- 2 dB")
        ax.set_ylim(lvl - 30, lvl + 10); ax.set_ylabel("|p/V| (dB re 1 Pa/V)")
        ax.set_title(f"System D, {title}: 150 Hz - 15 kHz spread {m[ang]['spread']:.1f} dB (1/6 oct)", fontsize=10)
        ax.grid(True, which="both", alpha=0.3); ax.legend(fontsize=8, ncol=5, loc="lower center")
    axs[1].set_xlim(50, 20000); axs[1].set_xlabel("Frequency (Hz)")
    save(fig, "xover_system.png")

    # ---- phase of the contributions around the crossovers (in phase = no cancellation)
    out, aux = X.evaluate(d, des, "on")
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)
    tau = 1.15 / 345                                    # same distance compensation as the LTspice files
    rot = np.exp(1j * 2 * np.pi * f * -tau)
    for u in ("woof", "mid", "tw", "sum"):
        a1.semilogx(f, np.degrees(np.angle(out[u] * rot)), color=COL[u], lw=1.2 if u != "sum" else 2, label=LAB[u])
    a1.set_ylabel("Phase (deg), d = -1.15 m"); a1.set_ylim(-190, 190); a1.legend(fontsize=8, ncol=4)
    for x in (m["x_wm"], m["x_mt"]):
        if x:
            a1.axvline(x, color="0.5", ls="--"); a2.axvline(x, color="0.5", ls="--")
    pw = 10 * np.log10(sum(np.abs(out[u]) ** 2 for u in ("woof", "mid", "tw")))
    a2.semilogx(f, db(out["sum"]) - pw, "k")
    a2.set_ylabel("sum - power sum (dB)"); a2.set_ylim(-12, 6)
    a2.set_title("0 dB = uncorrelated, +3 dB = in phase, < 0 = cancelling", fontsize=9)
    for a in (a1, a2):
        a.grid(True, which="both", alpha=0.3)
    a2.set_xlim(100, 20000); a2.set_xlabel("Frequency (Hz)")
    save(fig, "xover_phase.png")

    # ---- the filters themselves: electrical transfer and the load on amplifier channel 2
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)
    a1.semilogx(f, db(aux["HL"]), color=COL["woof"], label="digital LPF (woofer)")
    a1.semilogx(f, db(aux["HH"]), color="0.4", label="digital HPF (mid + tweeter)")
    a1.semilogx(f, db(aux["HH"] * aux["Tm"]), color=COL["mid"], label="HPF x passive LPF -> midrange terminals")
    a1.semilogx(f, db(aux["HH"] * aux["Tt"]), color=COL["tw"], label="HPF x passive HPF + pad -> tweeter terminals")
    a1.set_ylim(-40, 5); a1.set_ylabel("Voltage transfer (dB)"); a1.legend(fontsize=8)
    a2.semilogx(f, np.abs(aux["Zamp2"]), "k", label="|Z| seen by amplifier ch. 2")
    a2.semilogx(f, np.abs(d.zi["mid"]), color=COL["mid"], lw=0.8, ls="--", label="Zi midrange (Lab D)")
    a2.semilogx(f, np.abs(d.zi["tw"]), color=COL["tw"], lw=0.8, ls="--", label="Zi tweeter (Lab D)")
    a2.set_ylim(0, 30); a2.set_ylabel("|Z| (ohm)"); a2.legend(fontsize=8)
    for a in (a1, a2):
        a.grid(True, which="both", alpha=0.3)
    a2.set_xlim(50, 20000); a2.set_xlabel("Frequency (Hz)")
    save(fig, "xover_filters.png")
    t = tolerance(d, des)
    print(f"tolerance: 95 % band at most {t['band']:.1f} dB wide; coil resistance 0.3 / 0.6 ohm/mH changes the sum by "
          f"{t['dcr'][0.3]:.2f} / {t['dcr'][0.6]:.2f} dB at most (150 Hz - 15 kHz)")


TOL = {"L": 0.05, "C": 0.10, "R": 0.05}       # assumed: coils 5 %, (electrolytic/film) caps 10 %, resistors 5 %


def tolerance(d, des, n=400, seed=1):
    """Monte Carlo over the passive parts (uniform within TOL) and the coil resistance."""
    import copy
    rng = np.random.default_rng(seed)
    f = d.f
    nom = db(X.evaluate(d, des)[0]["sum"])
    runs = []
    for _ in range(n):
        t = copy.deepcopy(des)
        for u in ("mid", "tw"):
            for _, kind, name in X.TOPOLOGIES[t[u]["topo"]]:
                t[u]["vals"][name] *= 1 + TOL[kind] * rng.uniform(-1, 1)
            for k, v in (t[u].get("pad") or {}).items():
                if v:
                    t[u]["pad"][k] = v * (1 + TOL["R"] * rng.uniform(-1, 1))
        runs.append(db(X.evaluate(d, t)[0]["sum"]))
    runs = np.array(runs)
    lo, hi = np.percentile(runs, 2.5, axis=0), np.percentile(runs, 97.5, axis=0)
    dcr = {}
    for r in (0.3, 0.6):                          # ohm per mH: typical air-core / small iron-core coils
        t = copy.deepcopy(des); t["Rdcr"] = r
        dcr[r] = db(X.evaluate(d, t)[0]["sum"])
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(9, 6.5), sharex=True)
    a1.fill_between(f, lo, hi, color="0.75", label="95 % of the Monte Carlo runs")
    a1.semilogx(f, nom, "k", lw=1.5, label="nominal")
    a1.set_ylabel("|p/V| (dB)"); a1.legend(fontsize=8); m = np.median(nom[(f > 150) & (f < 15000)]); a1.set_ylim(m - 10, m + 6)
    a1.set_title(f"Component tolerances (L {TOL['L']:.0%}, C {TOL['C']:.0%}, R {TOL['R']:.0%}), {n} runs", fontsize=10)
    a2.semilogx(f, hi - nom, "0.4", label="97.5 % - nominal"); a2.semilogx(f, lo - nom, "0.4", ls="--", label="2.5 % - nominal")
    for r, c in zip(dcr, ("C1", "C3")):
        a2.semilogx(f, dcr[r] - nom, c, label=f"coil resistance {r} ohm/mH")
    a2.set_ylabel("change (dB)"); a2.set_ylim(-3, 3); a2.legend(fontsize=8)
    for a in (a1, a2):
        a.grid(True, which="both", alpha=0.3)
    a2.set_xlim(100, 20000); a2.set_xlabel("Frequency (Hz)")
    save(fig, "xover_tolerance.png")
    k = (f > 150) & (f < 15000)
    return dict(band=float(np.max(hi[k] - lo[k])), dcr={r: float(np.max(np.abs(v - nom)[k])) for r, v in dcr.items()})
