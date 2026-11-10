#!/usr/bin/env python3
"""What the anechoic measurement of the built system should show, state by state.

    python3 model_curves.py            # print the predictions, write model/expected_{on,off30}.csv
    python3 model_curves.py --plots    # also model/expected_{on,off30}.png

Uses ../design/xover.py and ../design/design.json unchanged. The woofer vent is PLUGGED in the
chamber (as in Lab E), so the box ratio is left out: these curves are the Lab E data run through
the MiniDSP filters, the woofer gain and the passive board. Every 'state' is one switch position of
the measurement plan in README.md (measure_project.m stores the same names).

Levels are p/V re the sound card line-out, exactly as Lab E measured them. On the day the MiniDSP
and the amplifier volume can shift the whole curve, so compare the shape and fit one level offset
(compare_project.m does that); do not expect the absolute dB to match.
"""
import csv, json, math, pathlib, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "design"))
import xover as X  # noqa: E402

OUT = HERE / "model"
STATES = ["woofer", "midtw", "mid", "tw", "all", "flipW", "flipT",
          "byp_woofer", "byp_mid", "byp_tw", "byp_midtw", "dir_woofer", "dir_mid", "dir_tw"]
LABEL = {"woofer": "woofer only (Out 2 muted)", "midtw": "mid + tweeter (Out 1 muted)",
         "mid": "midrange only (tweeter lead off)", "tw": "tweeter only (mid lead off)",
         "all": "all three", "flipW": "all, woofer inverted (Out 1 invert)",
         "flipT": "all, tweeter leads swapped",
         # placement check (MiniDSP bypassed): byp_* = through the board as built, dir_* = unit
         # wired straight to the amplifier (= the Lab E measurement itself)
         "byp_woofer": "woofer, MiniDSP bypassed", "byp_mid": "midrange via board, MiniDSP bypassed",
         "byp_tw": "tweeter via board, MiniDSP bypassed", "byp_midtw": "mid+tw via board, MiniDSP bypassed",
         "dir_woofer": "woofer straight (Lab E)", "dir_mid": "midrange straight (Lab E)",
         "dir_tw": "tweeter straight (Lab E)"}


def states(d, des, angle, Rdcr=None):
    des = json.loads(json.dumps(des))
    if Rdcr is not None:
        des["Rdcr"] = Rdcr
    out, ex = X.evaluate(d, des, angle)
    w, m, t = out["woof"], out["mid"], out["tw"]
    s = {"woofer": w, "midtw": m + t, "mid": m, "tw": t, "all": w + m + t,
         "flipW": -w + m + t, "flipT": w + m - t}
    tf = d.tf[angle]
    s.update({"byp_woofer": tf["woof"], "byp_mid": ex["Tm"] * tf["mid"], "byp_tw": ex["Tt"] * tf["tw"],
              "byp_midtw": ex["Tm"] * tf["mid"] + ex["Tt"] * tf["tw"],
              "dir_woofer": tf["woof"], "dir_mid": tf["mid"], "dir_tw": tf["tw"]})
    return s, ex


def db(x):
    return 20 * np.log10(np.abs(x))


def band(f, lo, hi):
    return (f >= lo) & (f <= hi)


def notch(f, flip, ref, lo, hi):
    """Deepest point of flip relative to the normal sum inside [lo, hi]."""
    k = np.where(band(f, lo, hi))[0]
    r = db(flip[k]) - db(ref[k])
    i = int(np.argmin(r))
    return float(f[k][i]), float(r[i]), float(db(flip[k][i]))


def main():
    des = json.loads((HERE.parent / "design" / "design.json").read_text())
    d = X.Data(box_ratio=False)          # vent plugged: no box ratio on the woofer
    f = d.f
    OUT.mkdir(exist_ok=True)
    print(X.describe(des))
    print("vent PLUGGED (anechoic chamber), levels re 1 Pa/V at the line-out as in Lab E\n")

    for ang in ("on", "off30"):
        s, ex = states(d, des, ang)
        with open(OUT / f"expected_{ang}.csv", "w", newline="") as fh:
            wr = csv.writer(fh)
            wr.writerow(["f"] + [f"{n}_{p}" for n in STATES for p in ("re", "im")])
            for i in range(len(f)):
                wr.writerow([f"{f[i]:.6g}"] + [f"{v:.8g}" for n in STATES for v in (s[n][i].real, s[n][i].imag)])
        k = band(f, 150, 15000)
        sm = X.smooth(f, db(s["all"]))[k]
        print(f"[{ang}] all three, 150 Hz-15 kHz, 1/6 oct: spread {sm.max() - sm.min():.1f} dB, "
              f"median {np.median(sm):.1f} dB re 1 Pa/V")
        if ang == "on":
            fw, dw, lw = notch(f, s["flipW"], s["all"], 200, 600)
            ft, dt, lt = notch(f, s["flipT"], s["all"], 2000, 6000)
            print(f"  woofer inverted : notch at {fw:.0f} Hz, {dw:.1f} dB below the normal sum")
            print(f"  tweeter swapped : notch at {ft:.0f} Hz, {dt:.1f} dB below the normal sum")
            for n, (lo, hi) in (("woofer", (100, 250)), ("midtw", (800, 2000)), ("tw", (6000, 12000))):
                print(f"  {LABEL[n]:34s} median {np.median(db(s[n][band(f, lo, hi)])):6.1f} dB in {lo}-{hi} Hz")
            # electrical check of the MiniDSP outputs (sine at fc, oscilloscope)
            fc, g = des["digital"]["fc"], des["digital"]["g_woof_dB"]
            HL = X.h_digital(np.array([fc]), fc, "LPF", des["digital"]["align"])[0]
            HH = X.h_digital(np.array([fc]), fc, "HPF", des["digital"]["align"])[0]
            print(f"  MiniDSP at {fc:.0f} Hz: Out 1 {db(HL) + g:.1f} dB (incl. {g:+.1f} dB gain), "
                  f"Out 2 {db(HH):.1f} dB, phase difference {math.degrees(np.angle(HL / HH)):.1f} deg")
            Z = ex["Zamp2"][band(f, 200, 15000)]
            print(f"  amplifier ch. 2 load: |Z| min {np.abs(Z).min():.2f} ohm (200 Hz-15 kHz)")
            # coil resistance: the basket coils are not ideal
            for r in (0.3, 0.6, 1.0):
                s2, _ = states(d, des, ang, Rdcr=r)
                dd = db(s2["all"][k]) - db(s["all"][k])
                print(f"  coils {r:.1f} ohm/mH: sum changes {dd.min():+.2f} .. {dd.max():+.2f} dB")
        print()
    write_zi(d, des)
    print("wrote", ", ".join(p.name for p in sorted(OUT.glob("expected_*.csv"))))
    if "--plots" in sys.argv:
        plots(d, des)


def write_zi(d, des):
    """Impedance amplifier channel 2 sees through the board (Zi/Nfield session, zinf_run.m).
    Zm = midrange branch only (tweeter lead off), Zt = tweeter branch only (mid lead off),
    Zamp2 = both. From the Lab D driver impedances, so ideal coils unless Rdcr is given."""
    f = d.f
    m, t = des["mid"], des["tw"]
    cols = {}
    for tag, r in (("", 0.0), ("_dcr06", 0.6)):
        _, Zm = X.ladder2(f, X.passive_parts(m["topo"], m["vals"], zobel=m.get("zobel")), d.zi["mid"], r)
        _, Zt = X.ladder2(f, X.passive_parts(t["topo"], t["vals"], pad=t.get("pad")), d.zi["tw"], r)
        cols["Zmid" + tag], cols["Ztw" + tag], cols["Zboth" + tag] = Zm, Zt, 1 / (1 / Zm + 1 / Zt)
    with open(OUT / "expected_zi.csv", "w", newline="") as fh:
        wr = csv.writer(fh)
        wr.writerow(["f"] + [f"{n}_{p}" for n in cols for p in ("re", "im")])
        for i in range(len(f)):
            wr.writerow([f"{f[i]:.6g}"] + [f"{v:.8g}" for n in cols for v in (cols[n][i].real, cols[n][i].imag)])
    Zb = np.abs(cols["Zboth"])
    i = int(np.argmin(Zb))
    print(f"board input (Zi/Nfield): |Z| min {Zb[i]:.2f} ohm at {f[i]:.0f} Hz, "
          f"|Z| at {f[0]:.0f} Hz {Zb[0]:.2f} ohm, at 10 kHz {Zb[np.argmin(abs(f - 1e4))]:.2f} ohm")
    if "--plots" in sys.argv:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(2, 1, figsize=(9, 6), sharex=True)
        for n, c in (("Zmid", "C1"), ("Ztw", "C2"), ("Zboth", "k")):
            ax[0].semilogx(f, np.abs(cols[n]), c, label=n)
            ax[0].semilogx(f, np.abs(cols[n + "_dcr06"]), c + ":", lw=1)
            ax[1].semilogx(f, np.degrees(np.angle(cols[n])), c)
        ax[0].set_ylabel("|Z| (ohm)"); ax[1].set_ylabel("phase (deg)"); ax[1].set_xlabel("frequency (Hz)")
        ax[0].set_title("Expected impedance at the board input (dotted: coils 0.6 ohm/mH)")
        ax[0].legend(fontsize=8)
        for a in ax:
            a.grid(True, which="both", alpha=0.3)
        fig.tight_layout(); fig.savefig(OUT / "expected_zi.png", dpi=130); plt.close(fig)


def plots(d, des):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    f = d.f
    for ang in ("on", "off30"):
        s, _ = states(d, des, ang)
        fig, ax = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
        for n, c in (("woofer", "C0"), ("mid", "C1"), ("tw", "C2"), ("all", "k")):
            ax[0].semilogx(f, db(s[n]), c, lw=1.6 if n == "all" else 1.1, label=LABEL[n])
        ax[0].semilogx(f, db(s["midtw"]), "C3--", lw=1, label=LABEL["midtw"])
        ax[1].semilogx(f, db(s["all"]), "k", lw=1.6, label=LABEL["all"])
        ax[1].semilogx(f, db(s["flipW"]), "C0", lw=1, label=LABEL["flipW"])
        ax[1].semilogx(f, db(s["flipT"]), "C2", lw=1, label=LABEL["flipT"])
        top = np.ceil(db(s["all"]).max() / 5) * 5 + 5
        for a in ax:
            a.set_ylim(top - 45, top); a.grid(True, which="both", alpha=0.3)
            a.set_ylabel("|p/V| (dB re 1 Pa/V)"); a.legend(fontsize=8, loc="lower center", ncol=2)
            a.axvspan(f[0], 125, color="0.9")
        ax[0].set_title(f"Expected anechoic result, vent plugged, {'0' if ang == 'on' else '30'} deg")
        ax[1].set_xlabel("frequency (Hz)"); ax[1].set_xlim(50, 20000)
        fig.tight_layout(); fig.savefig(OUT / f"expected_{ang}.png", dpi=130); plt.close(fig)
    print("wrote model/expected_on.png, model/expected_off30.png")


if __name__ == "__main__":
    main()
