#!/usr/bin/env python3
"""Task 1: LTspice analogy circuit of the System D woofer box (closed and vented).

    python3 gen_box_ltspice.py             # write Task1_WooferBox.asc/.plt with the fitted values
    python3 gen_box_ltspice.py --verify    # run LTspice headless, compare every step with box_model.py
    python3 gen_box_ltspice.py --preview   # draw the schematic to preview/*.png

Same drawing as the Lab E woofer (Lab E/ltspice/gen_labE_ltspice.py): IMPEDANCE analogy in all
three domains, couplings as controlled sources. The acoustic loop is new:

    U_D = S_D u  ->  pD --[ box: C_AB || R_AL || (M_AP + R_AP) ]-- pF --[ front radiation Z_ar ]-- 0

so V(pD, pF) is the box pressure and I(Vd3) the vent volume velocity U_P. All element values come
from box_model.fit() (Lab D impedances); nothing is typed in by hand.

.step param cfg:  0 = vents plugged (no leak, as measured), 1/2/3 = one vent at L = 160/200/240 mm
(effective M_AP from the fit). Change cfg 4's M_AP (Mx) to try a tuning that was not measured,
and `fill` for filling material (effective volume V_B * fill).

Outputs, for e_g = 1 V (the Lab D near-field H is in Pa/V, so they compare directly):
    V(SPL)     far field at 1 m, half space: jw rho (U_D - U_P) / (2 pi), as SPL (re 20 uPa)
    V(NFcone)  near field at the cone centre: jw rho U_D / (pi a_D), in Pa
    V(NFvent)  near field at the vent mouth:  jw rho U_P / (pi a_P), in Pa
    V(eg)/I(Vd1) = Z_E
"""
import math, pathlib, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402
import box_model as bm                       # noqa: E402

g.PINS["h"] = [(0, 16), (0, 96)]
NAME = "Task1_WooferBox"
MX = 52.0                                    # cfg 4: f_B ~ 28 Hz, the flat-f3 end of the sweep


def configs(RAB, QL, QP, MAP):
    """(label, box dict) for each step, the same dicts the closed form uses."""
    rows = [("plugged", bm.box_dict(RAB=RAB))]
    rows += [(f"L{int(L*1e3)}", bm.vent_box(RAB, QL, QP, m)) for L, m in MAP.items()]
    rows.append(("Mx", bm.vent_box(RAB, QL, QP, MX)))
    return rows


def table(vals):
    return "table(cfg," + ",".join(f"{k},{v:.6g}" for k, v in enumerate(vals)) + ")"


def build(drv, RAB, QL, QP, MAP):
    rows = configs(RAB, QL, QP, MAP)
    s = g.Sch()
    s.text(0, -544, f"Project Task 1 - System D woofer (Scan-Speak 26W/8534G00) in its {bm.VB*1e3:.1f} L box, closed or vented. "
                    "Driver and box values fitted to the Lab D impedances (box_model.py).")
    s.text(0, -512, "IMPEDANCE analogy in all three domains: electrical V = voltage, I = current | mechanical V = force, I = velocity | acoustical V = pressure, I = volume velocity")
    s.text(0, -464, f".param Vg=1 Re={bm.RE} Le={drv['Le']:.4g} Bl={drv['Bl']:.4g} Mmd={drv['Mmd']:.5g} Rms={drv['Rms']:.4g} Cms={drv['Cms']:.5g} "
                    f"Sd={bm.SD:.5g} aD={bm.AD:.5g} aP={bm.AP}", directive=True)
    s.text(0, -432, f".param rho={bm.RHO:.4f} c={bm.C0:.2f} VB={bm.VB:.5g} fill=1 CAB={{VB*fill/(rho*c**2)}}", directive=True)
    s.text(0, -400, ".param MAP=" + "{" + table([b["MAP"] or 1e9 for _, b in rows]) + "}", directive=True)
    s.text(0, -368, ".param RAP=" + "{" + table([b["RAP"] if b["MAP"] else 1.0 for _, b in rows]) + "}"
                    "  RAL={" + table([min(b["RAL"], 1e12) for _, b in rows]) + "}", directive=True)
    s.text(0, -336, ".step param cfg list 0 1 2 3 4", directive=True)
    s.text(0, -304, "cfg: " + ", ".join(f"{k} = {lab}" for k, (lab, _) in enumerate(rows))
                    + f"   (vented: Q_L {QL:.1f}, Q_P {QP:.1f} from the fit; plugged box fitted lossless.  cfg 4 = M_AP {MX:g} kg/m^4, edit to explore)")
    # ---- electrical loop
    s.vsrc(0, 0, "V_eg", "AC {Vg}")
    s.flag(64, 0, "eg"); s.wire(0, 0, 144, 0)
    x = s.vsense(144, 0, "Vd1"); s.wire(x, 0, x + 48, 0)
    x = s.hser("res", x + 48, 0, "R_Re", "{Re}"); s.wire(x, 0, x + 48, 0)
    x = s.hser("ind", x + 48, 0, "L_Le", "{Le}", g.NOLOSS); s.wire(x, 0, x + 128, 0); x += 128
    s.sym("h", "R0", x, -16, "H_emf", "Vd2 {Bl}", win=["WINDOW 0 24 40 Left 2", "WINDOW 3 24 72 Left 2"]); s.gnd(x, 80)
    # ---- mechanical loop
    mx = x + 400
    s.sym("h", "R0", mx, -16, "H_Bli", "Vd1 {Bl}", win=["WINDOW 0 24 40 Left 2", "WINDOW 3 24 72 Left 2"]); s.gnd(mx, 80)
    s.wire(mx, 0, mx + 192, 0)
    x = s.vsense(mx + 192, 0, "Vd2"); s.wire(x, 0, x + 48, 0)
    x = s.hser("ind", x + 48, 0, "L_Mmd", "{Mmd}", g.NOLOSS); s.wire(x, 0, x + 48, 0)
    x = s.hser("res", x + 48, 0, "R_Rms", "{Rms}"); s.wire(x, 0, x + 48, 0)
    x = s.hser("cap", x + 48, 0, "C_Cms", "{Cms}"); s.wire(x, 0, x + 304, 0)
    s.e_src(x + 304, 0, "E_SdpD", "{Sd}", "pD")
    # ---- acoustical loop: box network floating between pD and pF, front radiation from pF to ground
    ay = 640
    s.text(0, ay - 432, "acoustic load, in series: the box (C_AB || R_AL || vent M_AP + R_AP) between pD and pF, then the front radiation impedance Z_ar of the cone")
    s.text(0, ay - 400, "V(pD,pF) = box pressure;  I(Vd3) = U_P, the vent volume velocity (outward);  far field ~ U_D - U_P")
    s.f_inject(128, ay, "F_SdUd", "Vd2", "{Sd}")
    s.flag(192, ay, "pD"); s.wire(128, ay, 288, ay)
    xl = 288
    xr = s.hser("cap", xl, ay, "C_AB", "{CAB}", win=g.WIN_BELOW)          # rail: box compliance
    xr += 336
    s.wire(xl + 64, ay, xr, ay)
    s.hser("res", xl + 128, ay - 128, "R_AL", "{RAL}", win=g.WIN_ABOVE)   # leak
    s.wire(xl, ay, xl, ay - 128); s.wire(xl, ay - 128, xl + 128, ay - 128)
    s.wire(xl + 208, ay - 128, xr, ay - 128); s.wire(xr, ay - 128, xr, ay)
    vy = ay - 256                                                          # vent branch on top
    s.wire(xl, ay - 128, xl, vy)
    x = s.vsense(xl + 48, vy, "Vd3"); s.wire(xl, vy, xl + 48 - 16 + 16, vy)
    s.wire(x, vy, x + 32, vy)
    x = s.hser("ind", x + 32, vy, "L_MAP", "{MAP}", g.NOLOSS, win=g.WIN_ABOVE); s.wire(x, vy, x + 32, vy)
    x = s.hser("res", x + 32, vy, "R_AP", "{RAP}", win=g.WIN_ABOVE); s.wire(x, vy, xr, vy); s.wire(xr, vy, xr, ay - 128)
    s.flag(xr, ay, "pF"); s.wire(xr, ay, xr + 96, ay)
    MA1 = 8 * bm.RHO / (3 * math.pi ** 2 * bm.AD)
    s.text(0, ay + 368, f".param MA1={MA1:.5g} RA1={0.441*bm.RHO*bm.C0/bm.SD:.5g} RA2={bm.RHO*bm.C0/bm.SD:.5g} CA1={5.94*bm.AD**3/(bm.RHO*bm.C0**2):.5g}", directive=True)
    s.vshunt("ind", xr + 96, ay, "L_MA1", "{MA1}", g.NOLOSS)
    s.wire(xr + 96, ay, xr + 96 + g.PITCH, ay)
    s.radnet(xr + 96 + g.PITCH, ay, ("R_RA2", "{RA2}"), ("R_RA1", "{RA1}"), ("C_CA1", "{CA1}"))
    # ---- outputs
    ox, oy = 1760, ay
    s.text(ox - 96, oy - 496, "outputs (plot in dB): SPL = dB SPL at 1 m, half space; NFcone, NFvent = near-field pressure in Pa (dB re 1 Pa) for e_g = 1 V")
    s.sym("h", "R0", ox, oy - 16, "H_u", "Vd2 {Sd}", win=["WINDOW 0 24 40 Left 2", "WINDOW 3 24 72 Left 2"]); s.gnd(ox, oy + 80); s.flag(ox, oy, "UD")
    s.sym("h", "R0", ox, oy - 272, "H_up", "Vd3 1", win=["WINDOW 0 24 40 Left 2", "WINDOW 3 24 72 Left 2"]); s.gnd(ox, oy - 176); s.flag(ox, oy - 256, "UP")
    p = s.sym("e", "R0", ox + 400, oy - 16, "E_SPL", "Laplace=kff*s")      # controlled by V(UD, UP)
    s.gnd(*p[1]); s.flag(*p[0], "SPL")
    s.wire(p[2][0], p[2][1], p[2][0] - 64, p[2][1]); s.flag(p[2][0] - 64, p[2][1], "UD")
    s.wire(p[3][0], p[3][1], p[3][0] - 64, p[3][1]); s.flag(p[3][0] - 64, p[3][1], "UP")
    s.e_src(ox + 880, oy, "E_NFc", "Laplace=knc*s", "UD"); s.flag(ox + 880, oy, "NFcone")
    s.e_src(ox + 880, oy - 256, "E_NFv", "Laplace=knv*s", "UP"); s.flag(ox + 880, oy - 256, "NFvent")
    s.text(0, ay + 400, ".param kff={rho/(2*pi*20u)} knc={rho/(pi*aD)} knv={rho/(pi*aP)}", directive=True)
    s.text(0, ay + 432, ".ac dec 200 5 500", directive=True)
    s.text(0, ay + 480, "SPL: p = j w rho (U_D - U_P) / (2 pi r), r = 1 m, half space (box on the floor / large baffle), no baffle step, no room.")
    s.text(0, ay + 512, "NF: p = j w rho U / (pi a) at the centre of a baffled piston, ka << 1 (Keele). Compare with Lab D labD_nf_*.mat, which are p/V in Pa/V.")
    s.dump(HERE / f"{NAME}.asc")
    g.plt(HERE / f"{NAME}.plt", [(["V(SPL)"], (50, 100)), (["V(NFcone)", "V(NFvent)"], (0.01, 10)), (["V(eg)/I(Vd1)"], (1, 200))], (5, 500))
    return HERE / f"{NAME}.asc", rows


def steps(d):
    """Split a stepped AC raw (frequency restarts every step) into one dict per step."""
    f = [v.real for v in d["frequency"]]
    cut = [0] + [j for j in range(1, len(f)) if f[j] < f[j - 1]] + [len(f)]
    keys = [k for k in d if not k.startswith("_")]
    return [{k: np.array(d[k][a:b]) for k in keys} for a, b in zip(cut[:-1], cut[1:])]


def verify(asc, rows, drv):
    st = steps(g.run_ltspice(asc))
    ok = True
    for (lab, bx), d in zip(rows, st):
        f = d["frequency"].real
        r = bm.system(f, drv, bx)
        checks = ((d["v(eg)"] / d["i(vd1)"], r["ZE"]), (d["v(spl)"] * 20e-6, r["p1m"]), (d["v(nfcone)"], r["nf_cone"]))
        worst = max(np.max(np.abs(got / want - 1)) for got, want in checks)
        if bx["MAP"]:
            worst = max(worst, np.max(np.abs(d["v(nfvent)"] / r["nf_vent"] - 1)))
        f3, rip, _ = bm.f3_and_ripple(f, d["v(spl)"])
        good = worst < 2e-3; ok &= good
        fb = f"f_B {bm.fb_of(bx['MAP']):.1f} Hz" if bx["MAP"] else "closed   "
        print(f"  {'OK ' if good else 'BAD'} cfg {lab:8s} {fb}: worst deviation {worst:.1e};  f_3 {f3:.1f} Hz, ripple {rip:+.2f} dB")
    print("ALL OK" if ok else "MISMATCH")
    return ok


if __name__ == "__main__":
    drv, RAB, QL, QP, MAP, _ = bm.fit()
    asc, rows = build(drv, RAB, QL, QP, MAP)
    print("wrote", asc.name)
    if "--preview" in sys.argv:
        import preview_asc as pv
        pv.HERE = HERE
        pv.main(str(asc))
    if "--verify" in sys.argv:
        sys.exit(0 if verify(asc, rows, drv) else 1)
