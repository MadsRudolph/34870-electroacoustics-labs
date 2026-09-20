#!/usr/bin/env python3
"""Lab C: LTspice model of the two B&K condenser microphones (4133, 4134) driven by an
electrostatic actuator, i.e. a pressure applied straight to the diaphragm (no sound field,
so no scattering block T(s)).

    python3 gen_labC_ltspice.py            # write LabC_CondenserMics.asc / .plt
    python3 gen_labC_ltspice.py --verify   # run LTspice headless, compare with the closed form

The ONLY numbers to type in after the lab are the measured resonance frequency fs and Q of
each microphone (.param fs33 Q33 fs34 Q34 on the sheet, or FS_Q below and regenerate). The
backplate's acoustic mass M_AS and resistance R_AS follow from them inside LTspice:

    M_MT = 1 / ((2 pi fs)^2 C_MT)          R_MT = sqrt(M_MT / C_MT) / Q
    M_AS = (M_MT - M_MD) / S_D^2 - M_A1     R_AS = R_MT / S_D^2           (R_MD = 0 in the brief)

Three domains, same conventions as Lab A: mechanical side in the MOBILITY analogy (node
voltage = diaphragm velocity), acoustic side in the IMPEDANCE analogy (node voltage = pressure).
"""
import math, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402  (schematic builder + headless runner from Lab A)

RHO, C0, EPS0 = 1.18, 344.0, 8.854e-12
# data given in the brief (identical for both microphones)
P = dict(a=8.95e-3 / 2, x0=20.77e-6, E=200.0, MMD=1.5e-6, CMD=0.02e-3, V=126.4e-9, RL=10e9)
# PLACEHOLDERS until measured: (fs [Hz], Q). 4133 = free-field type (heavily damped), 4134 = pressure type
FS_Q = {"33": (20e3, 0.45), "34": (20e3, 0.95)}
NAMES = {"33": "B&K 4133 (S/N 591628)", "34": "B&K 4134 (S/N 1534527)"}


def derived(fs, Q):
    SD = math.pi * P["a"] ** 2
    CAB = P["V"] / (RHO * C0 ** 2)
    MA1 = 0.6133 * RHO / (math.pi * P["a"])
    CMT = 1 / (1 / P["CMD"] + SD ** 2 / CAB)
    MMT = 1 / ((2 * math.pi * fs) ** 2 * CMT)
    return dict(SD=SD, CAB=CAB, MA1=MA1, CMT=CMT, MMT=MMT, MAS=(MMT - P["MMD"]) / SD ** 2 - MA1,
                RAS=math.sqrt(MMT / CMT) / Q / SD ** 2, CE0=EPS0 * SD / P["x0"], M=P["E"] * SD * CMT / P["x0"],
                f0_no_backplate=1 / (2 * math.pi * math.sqrt((P["MMD"] + SD ** 2 * MA1) * CMT)))


def mic(s, oy, k):
    """one microphone: acoustic branch, mechanical node, electrical node"""
    s.text(0, oy - 176, f"{NAMES[k]}:  type the measured values here ->", size=2)
    s.text(0, oy - 144, f".param fs{k}={FS_Q[k][0]:g} Q{k}={FS_Q[k][1]:g}", directive=True)
    s.text(0, oy - 112, f".param MMT{k}=1/((2*pi*fs{k})**2*CMT) MAS{k}=(MMT{k}-MMD)/SD**2-MA1 RAS{k}=sqrt(MMT{k}/CMT)/Q{k}/SD**2", directive=True)
    # --- acoustic: U = SD*u_D injected into node p = (back pressure - front pressure); the actuator is the 1 Pa source
    x = 128
    s.g_inject(x, oy, f"G_U{k}", "{SD}", f"u_D{k}")
    s.flag(x + 96, oy, f"p{k}")
    s.wire(x, oy, x + 224, oy)
    x1 = s.hser("ind", x + 224, oy, f"L_MA1_{k}", "{MA1}", g.NOLOSS); s.wire(x1, oy, x1 + 64, oy)
    x2 = s.hser("res", x1 + 64, oy, f"R_RAS{k}", "{RAS%s}" % k); s.wire(x2, oy, x2 + 64, oy)
    x3 = s.hser("ind", x2 + 64, oy, f"L_MAS{k}", "{MAS%s}" % k, g.NOLOSS); s.wire(x3, oy, x3 + 64, oy)
    x4 = s.hser("cap", x3 + 64, oy, f"C_CAB{k}", "{CAB}", "Rpar=1e15"); s.wire(x4, oy, x4 + 176, oy)
    s.vsrc(x4 + 176, oy, f"V_act{k}", "AC 1 180")
    s.text(x4 + 230, oy + 16, "actuator = 1 Pa on the diaphragm", size=1)
    # --- mechanical mobility node
    mx = x4 + 640
    s.flag(mx, oy, f"u_D{k}")
    s.wire(mx - 64, oy, mx + 2 * g.PITCH + 304, oy)
    s.shunts(mx + 96, oy, [("cap", f"C_MMD{k}", "{MMD}"), ("ind", f"L_CMD{k}", "{CMD}", g.NOLOSS)])
    s.g_draw(mx + 96 + g.PITCH + 304, oy, f"G_f{k}", "{SD}", f"p{k}")
    s.wire(mx - 64, oy, mx - 64, oy)
    # --- electrical node: Norton source (E*CE0/x0)*u_D into C_E0 || R_L
    ex = mx + 96 + g.PITCH + 304 + 560
    s.g_inject(ex, oy, f"G_e{k}", "{E*CE0/x0}", f"u_D{k}")
    s.wire(ex, oy, ex + 2 * g.PITCH + 96, oy)
    s.flag(ex + 112, oy, f"out{k}")
    s.shunts(ex + g.PITCH, oy, [("cap", f"C_CE0_{k}", "{CE0}"), ("res", f"R_RL{k}", "{RL}")])


def build():
    s = g.Sch()
    s.text(0, -420, "Lab C - condenser microphones 4133 / 4134 excited by an electrostatic actuator (pressure applied directly to the diaphragm, no T(s) block)")
    s.text(0, -388, "left: ACOUSTIC, impedance analogy (V = pressure, I = volume velocity)   middle: MECHANICAL, mobility analogy (V = diaphragm velocity, I = force)   right: ELECTRICAL (V(out) = open-circuit output per Pa)")
    s.text(0, -340, f".param a={P['a']:g} x0={P['x0']:g} E={P['E']:g} MMD={P['MMD']:g} CMD={P['CMD']:g} Vb={P['V']:g} RL={P['RL']:g} rho={RHO} c={C0}", directive=True)
    s.text(0, -308, ".param SD=pi*a**2 CAB=Vb/(rho*c**2) MA1=0.6133*rho/(pi*a) CMT=1/(1/CMD+SD**2/CAB) CE0=8.854e-12*SD/x0", directive=True)
    mic(s, 0, "33")
    mic(s, 520, "34")
    s.text(0, 800, ".ac dec 200 20 60k", directive=True)
    s.text(0, 848, "plot V(out33) V(out34): magnitude in dB re 1 V/Pa and phase. Low-frequency level = E*SD*CMT/x0 = 11.1 mV/Pa (-39.1 dB), below the nominal 12.5 mV/Pa: see the appendix of the brief.")
    s.text(0, 880, "fs = where the phase has dropped 90 deg from its mid-band value,  Q = |H(fs)| / |H(f << fs)| (linear).  A 180 deg offset against the measurement is only the ground convention.")
    s.dump(HERE / "LabC_CondenserMics.asc")
    g.plt(HERE / "LabC_CondenserMics.plt", [(["V(out33)", "V(out34)"], (1e-3, 0.1))], (20, 60000))


def verify():
    import cmath
    d = g.run_ltspice(HERE / "LabC_CondenserMics.asc"); f = [x.real for x in d["frequency"]]; ok = True
    for k in ("33", "34"):
        fs, Q = FS_Q[k]; D = derived(fs, Q); fl = 1 / (2 * math.pi * P["RL"] * D["CE0"])
        worst = 0
        for fi, v in zip(f, d[f"v(out{k})"]):
            x = fi / fs
            ref = D["M"] / complex(1 - x * x, x / Q) * (1j * fi / fl) / (1 + 1j * fi / fl)
            worst = max(worst, abs(abs(v) / abs(ref) - 1), abs(cmath.phase(v / ref)))
        i = min(range(len(f)), key=lambda j: abs(f[j] - fs)); ph = math.degrees(cmath.phase(d[f"v(out{k})"][i]))
        good = worst < 5e-3; ok &= good
        print(f"  {'OK ' if good else 'BAD'} {NAMES[k]}: worst deviation from M/(1-x^2+jx/Q) {worst:.2e}; phase at fs {ph:.1f} deg; "
              f"|H(fs)|/|H(low)| = {abs(d[f'v(out{k})'][i]) / D['M']:.3f} (Q = {Q});  M_AS = {D['MAS']:.1f} kg/m4, R_AS = {D['RAS']:.3g} Pa s/m3")
    print("ALL OK" if ok else "MISMATCH"); return ok


if __name__ == "__main__":
    build()
    D = derived(*FS_Q["33"])
    print(f"S_D = {D['SD']:.4g} m2, C_AB = {D['CAB']:.4g}, M_A1 = {D['MA1']:.4g}, C_MT = {D['CMT']:.4g} m/N, C_E0 = {D['CE0']*1e12:.2f} pF, "
          f"M = {D['M']*1e3:.2f} mV/Pa, resonance without any backplate mass = {D['f0_no_backplate']/1e3:.1f} kHz")
    if "--verify" in sys.argv:
        sys.exit(0 if verify() else 1)
