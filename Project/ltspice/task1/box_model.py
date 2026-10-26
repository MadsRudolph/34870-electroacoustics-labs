#!/usr/bin/env python3
"""Task 1: closed-form model of the System D woofer box, fitted to Lab D.

    python3 box_model.py            # fit, print the parameters and the tuning table
    python3 box_model.py --plots    # also write ../../figures/task1_*.png

Woofer Scan-Speak 26W/8534G00 in the 88.1 L box. IMPEDANCE analogy, everything referred to the
acoustic domain behind the cone (same drawing as Lab E / Problems 7.4):

    electrical: e_g -> R_E -> L_E -> Bl*u
    mechanical: M_MD + R_MS + C_MS + S_D^2 (Z_front + Z_rear)
    rear (box): U_D into node p_B; to ground through C_AB (V_B * fill), the leak R_AL and the
                vent branch M_AP + R_AP. U_P = p_B / (jw M_AP + R_AP) leaves through the vent.
    far field:  p ~ jw rho (U_D - U_P) / (2 pi r)        (half space)
    near field: p ~ jw rho U / (pi a) at the centre of a baffled piston of radius a (ka << 1)

Fitting, in three steps, each on the complex Z (log |Z| and phase, 8-150 Hz):
  1. free air  -> Bl, M_MD, C_MS, R_MS, L_E        (both sides loaded by an unbaffled piston)
  2. closed    -> box loss R_AB in series with C_AB  (driver from step 1, nothing else free)
  3. vents     -> box leak Q_L and vent loss Q_P (shared) and one effective M_AP per length
Then the near field of cone and vent is predicted (not fitted) and compared with the
measurement in absolute Pa/V, which is the validation the guide asks for.
"""
import math, pathlib, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
CSV = HERE.parents[1] / "data" / "csv"
FIG = HERE.parents[1] / "figures"

T = 20.0                                      # Lab D: temperature not recorded
C0 = 331.3 * math.sqrt(1 + T / 273.15)
RHO = 1.2041 * 293.15 / (273.15 + T)
RE = 5.7                                      # multimeter
SD = math.pi * 0.211 ** 2 / 4                 # data sheet effective diameter 211 mm
AD = math.sqrt(SD / math.pi)
VB = 0.435 * 0.45 * 0.45                      # inner volume, no filling
AP = 0.065 / 2                                # the vent we measured
LENGTHS = (0.160, 0.200, 0.240)


def load(name):
    d = np.genfromtxt(CSV / f"{name}.csv", delimiter=",", names=True)
    return d["f"], d["re"] + 1j * d["im"]


# ---------------------------------------------------------------- acoustic elements
def z_piston(w, a, baffled=True):
    """Radiation impedance of one face of a piston (Lecture 7 low-frequency network)."""
    S = math.pi * a ** 2
    MA1 = 8 * RHO / (3 * math.pi ** 2 * a) * (1 if baffled else 0.6133 / 0.8488)
    RA1, RA2 = 0.441 * RHO * C0 / S, RHO * C0 / S
    CA1 = 5.94 * a ** 3 / (RHO * C0 ** 2)
    jw = 1j * w
    return 1 / (1 / (jw * MA1) + 1 / (RA2 + 1 / (1 / RA1 + jw * CA1)))


def vent_mass(L, a, k_end, n=1):
    """n equal tubes in parallel: M_AP = rho (L + k_end a) / (n pi a^2)."""
    return RHO * (L + k_end * a) / (n * math.pi * a ** 2)


def two_vent_mass(L1, a1, L2, a2, k_end):
    """Two different tubes in parallel combine like two inductors."""
    m1, m2 = vent_mass(L1, a1, k_end), vent_mass(L2, a2, k_end)
    return m1 * m2 / (m1 + m2)


# ---------------------------------------------------------------- the system
def system(f, drv, box):
    """drv: Bl, Mmd, Cms, Rms, Le.  box: None (free air) or dict with
    CAB, RAB (series with CAB), RAL (leak, parallel), MAP (None = closed), RAP."""
    w = 2 * np.pi * np.asarray(f, float); jw = 1j * w
    if box is None:
        Zfront = Zrear = z_piston(w, AD, baffled=False)
        Zbox = Zrear
    else:
        Zfront = z_piston(w, AD)
        Yb = 1 / (box["RAB"] + 1 / (jw * box["CAB"])) + 1 / box["RAL"]
        if box.get("MAP") is not None:
            Yb = Yb + 1 / (jw * box["MAP"] + box["RAP"])
        Zbox = 1 / Yb
    ZM = jw * drv["Mmd"] + drv["Rms"] + 1 / (jw * drv["Cms"]) + SD ** 2 * (Zfront + Zbox)
    ZE = RE + jw * drv["Le"] + drv["Bl"] ** 2 / ZM
    i = 1 / ZE                                  # e_g = 1 V
    UD = SD * drv["Bl"] * i / ZM
    pB = Zbox * UD
    UP = pB / (jw * box["MAP"] + box["RAP"]) if box and box.get("MAP") is not None else 0 * UD
    return dict(ZE=ZE, UD=UD, UP=UP,
                p1m=jw * RHO * (UD - UP) / (2 * np.pi),          # 1 m, half space, 1 V
                nf_cone=jw * RHO * UD / (np.pi * AD),
                nf_vent=jw * RHO * UP / (np.pi * box["ap"]) if box and box.get("MAP") is not None else 0 * UD)


def box_dict(fill=1.0, RAB=0.0, QL=1e9, MAP=None, fb_ref=20.0, ap=AP, RAP=0.0):
    CAB = VB * fill / (RHO * C0 ** 2)
    RAL = QL / (2 * math.pi * fb_ref * CAB)    # leak Q at the vent tuning (Lecture 8 convention)
    return dict(CAB=CAB, RAB=RAB, RAL=RAL, MAP=MAP, RAP=RAP, ap=ap)


# ---------------------------------------------------------------- fitting
def nelder_mead(fun, x0, step=0.1, iters=4000, tol=1e-10):
    n = len(x0); pts = [np.array(x0, float)]
    for k in range(n):
        x = np.array(x0, float); x[k] += step; pts.append(x)
    vals = [fun(p) for p in pts]
    for _ in range(iters):
        o = np.argsort(vals); pts = [pts[i] for i in o]; vals = [vals[i] for i in o]
        if abs(vals[-1] - vals[0]) < tol * (abs(vals[0]) + 1e-12):
            break
        c = np.mean(pts[:-1], axis=0)
        xr = c + (c - pts[-1]); fr = fun(xr)
        if fr < vals[0]:
            xe = c + 2 * (c - pts[-1]); fe = fun(xe)
            pts[-1], vals[-1] = (xe, fe) if fe < fr else (xr, fr)
        elif fr < vals[-2]:
            pts[-1], vals[-1] = xr, fr
        else:
            xc = c + 0.5 * (pts[-1] - c); fc = fun(xc)
            if fc < vals[-1]:
                pts[-1], vals[-1] = xc, fc
            else:
                pts = [pts[0] + 0.5 * (p - pts[0]) for p in pts]; vals = [fun(p) for p in pts]
    return pts[int(np.argmin(vals))]


def zerr(Zm, Zs):
    return np.mean(np.abs(np.log(Zs / Zm)) ** 2)    # log|Z| and phase (rad) together


def band(f, Z, lo=8, hi=150):
    k = (f >= lo) & (f <= hi)
    return f[k], Z[k]


def fit():
    # start from analyse_labD (fs 22.72, Qms 9.95, Qes 0.511, fc 42.0) and the data sheet L_E
    fs, Qms, Qes, fc = 22.72, 9.95, 0.511, 42.01
    Vas = VB * ((fc / fs) ** 2 - 1)
    Cms = Vas / (RHO * C0 ** 2) / SD ** 2; ws = 2 * math.pi * fs; Mms = 1 / (ws ** 2 * Cms)
    x0 = np.log([math.sqrt(ws * RE * Mms / Qes), Mms, Cms, ws * Mms / Qms, 0.96e-3])
    keys = ("Bl", "Mmd", "Cms", "Rms", "Le")
    ff, Zf = band(*load("Z_woofer_free"))
    fcl, Zc = band(*load("Z_woofer_closed"))

    # 1+2 together: free air and closed box share the driver; the box adds only R_AB
    def cost12(x):
        d = dict(zip(keys, np.exp(x[:5])))
        bx = box_dict(RAB=math.exp(x[5]))
        return zerr(Zf, system(ff, d, None)["ZE"]) + zerr(Zc, system(fcl, d, bx)["ZE"])
    x = nelder_mead(cost12, list(x0) + [math.log(50.0)])
    x = nelder_mead(cost12, x, step=0.02)
    drv = dict(zip(keys, np.exp(x[:5]))); RAB = math.exp(x[5])

    # 3: vents. The telescopic tube does not follow M_AP = rho (L + 1.46 a)/S_P (the measured f_B
    # moves half as much with L as that predicts), so each length gets its own effective M_AP.
    # Shared: box leak Q_L and vent loss Q_P = w_B M_AP / R_AP. The plugged box is nearly
    # lossless (step 2), the open one is not: the loss comes with the open vent (port losses),
    # so these two Qs belong to the vented configurations only.
    vents = [band(*load(f"Z_vent_L{int(L*1e3)}"), 5, 150) for L in LENGTHS]

    def boxes(y):
        QL, QP = math.exp(y[0]), math.exp(y[1])
        out = []
        for m in np.exp(y[2:]):
            wb = 1 / math.sqrt(m * VB / (RHO * C0 ** 2))
            out.append(box_dict(RAB=RAB, QL=QL, MAP=m, RAP=wb * m / QP))
        return out

    def cost3(y):
        e = 0
        for (fv, Zv), bx in zip(vents, boxes(y)):
            e += zerr(Zv, system(fv, drv, bx)["ZE"])
        return e
    y0 = [math.log(20.0), math.log(10.0)] + [math.log(vent_mass(L, AP, 1.46)) for L in LENGTHS]
    y = nelder_mead(cost3, y0, step=0.2)
    y = nelder_mead(cost3, y, step=0.02)
    QL, QP = np.exp(y[:2])
    MAP = dict(zip(LENGTHS, np.exp(y[2:])))
    return drv, RAB, QL, QP, MAP, dict(free=cost12(x), vents=cost3(y))


def vent_box(RAB, QL, QP, MAP, fill=1.0):
    wb = 1 / math.sqrt(MAP * VB * fill / (RHO * C0 ** 2))
    return box_dict(fill=fill, RAB=RAB, QL=QL, MAP=MAP, RAP=wb * MAP / QP)


def ts(drv, RAB):
    Mms = drv["Mmd"] + 2 * SD ** 2 * z_piston(2 * math.pi * 20, AD, False).imag / (2 * math.pi * 20)
    fs = 1 / (2 * math.pi * math.sqrt(Mms * drv["Cms"])); ws = 2 * math.pi * fs
    return dict(fs=fs, Mms=Mms, Qms=ws * Mms / drv["Rms"], Qes=ws * Mms * RE / drv["Bl"] ** 2,
                Vas=RHO * C0 ** 2 * SD ** 2 * drv["Cms"])


def fb_of(MAP, fill=1.0):
    return 1 / (2 * math.pi * math.sqrt(MAP * VB * fill / (RHO * C0 ** 2)))


def f3_and_ripple(f, p, ref_band=(150, 300)):
    """f_3 against the mid-band level (mean over ref_band) and the peak above it (ripple)."""
    L = 20 * np.log10(np.abs(p)); k = (f >= ref_band[0]) & (f <= ref_band[1])
    ref = np.mean(L[k]); rel = L - ref
    below = np.where((rel < -3) & (f < ref_band[0]))[0]
    f3 = f[below[-1] + 1] if len(below) else f[0]
    ripple = rel[f < ref_band[0]].max()
    return f3, ripple, ref


if __name__ == "__main__":
    drv, RAB, QL, QP, MAP, err = fit()
    t = ts(drv, RAB)
    print(f"air: T {T} C, c {C0:.1f} m/s, rho {RHO:.4f};  V_B {VB*1e3:.1f} L, S_D {SD*1e4:.0f} cm^2")
    print(f"driver fit (free + closed): Bl {drv['Bl']:.2f} Tm, M_MD {drv['Mmd']*1e3:.1f} g, C_MS {drv['Cms']*1e3:.3f} mm/N, "
          f"R_MS {drv['Rms']:.2f} kg/s, L_E {drv['Le']*1e3:.2f} mH, box R_AB {RAB:.1f} Pa s/m^3")
    print(f"   -> f_S {t['fs']:.2f} Hz, Q_MS {t['Qms']:.2f}, Q_ES {t['Qes']:.3f}, V_AS {t['Vas']*1e3:.1f} L  (cost {err['free']:.4f})")
    print(f"vent fit: Q_L {QL:.1f}, Q_P {QP:.1f}  (cost {err['vents']:.4f})")
    for L, m in MAP.items():
        print(f"   L = {L*1e3:.0f} mm: M_AP {m:6.1f} kg/m^4 (formula, a = 32.5 mm: {vent_mass(L, AP, 1.46):6.1f})  f_B {fb_of(m):.1f} Hz")
    f = np.geomspace(5, 400, 2000)
    print("\nconfig                         f_B Hz   f_3 Hz   ripple dB")
    rows = [("closed", box_dict(RAB=RAB))]
    rows += [(f"1 vent, L = {L*1e3:.0f} mm", vent_box(RAB, QL, QP, m)) for L, m in MAP.items()]
    for name, bx in rows:
        r = system(f, drv, bx); f3, rip, _ = f3_and_ripple(f, r["p1m"])
        fb = fb_of(bx["MAP"]) if bx["MAP"] else float("nan")
        print(f"{name:30s} {fb:6.1f}   {f3:6.1f}   {rip:+6.2f}")
    mac = {"fS": f"{t['fs']:.2f}", "QMS": f"{t['Qms']:.2f}", "QES": f"{t['Qes']:.3f}", "QTS": f"{1/(1/t['Qms']+1/t['Qes']):.3f}",
           "VAS": f"{t['Vas']*1e3:.0f}", "Bl": f"{drv['Bl']:.2f}", "MMD": f"{drv['Mmd']*1e3:.1f}", "MMS": f"{t['Mms']*1e3:.1f}",
           "CMS": f"{drv['Cms']*1e3:.3f}", "RMS": f"{drv['Rms']:.2f}", "LE": f"{drv['Le']*1e3:.2f}",
           "QL": f"{QL:.1f}", "QP": f"{QP:.0f}", "VB": f"{VB*1e3:.1f}"}
    for L, m in MAP.items():
        tag = {0.16: "A", 0.2: "B", 0.24: "C"}[round(L, 2)]
        mac[f"MAP{tag}"] = f"{m:.1f}"; mac[f"MAPformula{tag}"] = f"{vent_mass(L, AP, 1.46):.1f}"; mac[f"fB{tag}"] = f"{fb_of(m):.1f}"
    for name, bx in rows:
        r = system(f, drv, bx); f3, rip, _ = f3_and_ripple(f, r["p1m"])
        tag = {"closed": "Cl", "1 vent, L = 160 mm": "A", "1 vent, L = 200 mm": "B", "1 vent, L = 240 mm": "C"}[name]
        mac[f"fthree{tag}"] = f"{f3:.1f}"; mac[f"ripple{tag}"] = f"{rip:+.1f}"
    out = HERE.parents[1] / "report" / "results_task1.tex"
    out.write_text("% written by ltspice/task1/box_model.py; do not edit\n" + "".join(f"\\newcommand{{\\b{k}}}{{{v}}}\n" for k, v in mac.items()))
    print("wrote", out.name)
    if "--plots" in sys.argv:
        import plots
        plots.main(drv, RAB, QL, QP, MAP)
