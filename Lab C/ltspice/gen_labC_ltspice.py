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

Drawn like the lecture circuits: an electrical loop, a mechanical loop (IMPEDANCE analogy: node
voltage = force, loop current = velocity) and the acoustic network below (IMPEDANCE analogy: node
voltage = pressure), tied together by controlled sources driven by a 0 V ammeter in the mechanical loop.
"""
import math, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402  (schematic builder + headless runner from Lab A)

RHO, C0, EPS0 = 1.18, 344.0, 8.854e-12
# data given in the brief (identical for both microphones)
P = dict(a=8.95e-3 / 2, x0=20.77e-6, E=200.0, MMD=1.5e-6, CMD=0.02e-3, V=126.4e-9, RL=10e9)
# measured 29-Sep-2026 (matlab/part3_mic_responses.m): fs from the -90 deg phase crossing, Q = |H(fs)|/|H(low f)|
FS_Q = {"33": (22930, 0.340), "34": (20221, 0.835)}
NAMES = {"33": "B&K 4133, free field (Mic 2 in the lab)", "34": "B&K 4134, pressure field (Mic 1 in the lab)"}


def derived(fs, Q):
    SD = math.pi * P["a"] ** 2
    CAB = P["V"] / (RHO * C0 ** 2)
    MA1 = 0.6133 * RHO / (math.pi * P["a"])
    CMT = 1 / (1 / P["CMD"] + SD ** 2 / CAB)
    MMT = 1 / ((2 * math.pi * fs) ** 2 * CMT)
    return dict(SD=SD, CAB=CAB, MA1=MA1, CMT=CMT, MMT=MMT, MAS=(MMT - P["MMD"]) / SD ** 2 - MA1,
                RAS=math.sqrt(MMT / CMT) / Q / SD ** 2, CE0=EPS0 * SD / P["x0"], M=P["E"] * SD * CMT / P["x0"],
                f0_no_backplate=1 / (2 * math.pi * math.sqrt((P["MMD"] + SD ** 2 * MA1) * CMT)))


class Asc:
    """minimal .asc writer, so the layout can follow the lecture drawings exactly"""
    def __init__(self):
        self.l = ["Version 4.1", "SHEET 1 2400 2000"]

    def w(self, x1, y1, x2, y2, oy=0):
        self.l.append(f"WIRE {x1} {y1 + oy} {x2} {y2 + oy}")

    def flag(self, x, y, name, oy=0):
        self.l.append(f"FLAG {x} {y + oy} {name}")

    def sym(self, kind, x, y, rot, name, value, oy=0, win=(), spice=None):
        self.l.append(f"SYMBOL {kind} {x} {y + oy} {rot}")
        self.l += [f"WINDOW {w}" for w in win]
        self.l += [f"SYMATTR InstName {name}", f"SYMATTR Value {value}"]
        if spice:
            self.l.append(f"SYMATTR SpiceLine {spice}")

    def text(self, x, y, body, size=2, directive=False):
        self.l.append(f"TEXT {x} {y} Left {size} {'!' if directive else ';'}{body}")

    def dump(self, path):
        pathlib.Path(path).write_text("\n".join(self.l) + "\n")


H_ = ("0 0 56 VBottom 2", "3 32 56 VTop 2")        # label windows for horizontal R (R90)
HL = ("0 32 56 VTop 2", "3 5 56 VBottom 2")        # ... for horizontal L (R270)
HV = ("0 -32 56 VBottom 2", "3 32 56 VTop 2")      # ... for a horizontal V source (R90)


def mic(a, oy, k):
    """One microphone in the lecture layout: electrical loop (top left), mechanical loop (top right),
    acoustic network (bottom: back | diaphragm | front). The domains are tied together by
    controlled sources and the 0 V ammeter Vu (its current is the diaphragm velocity u_D):
      mechanical force   E_F = S_D (p_front - p_back)          (VCVS, impedance analogy: V = force, I = velocity)
      volume velocity    F_U = S_D u_D, out of front into back  (CCCS)
      electrical output  F_e = (E C_E0 / x0) u_D into C_E0 || R_L (CCCS, Norton form)"""
    a.text(-128, oy - 136, f"{NAMES[k]}   <- measured values:", size=2)
    a.text(-128, oy - 104, f".param fs{k}={FS_Q[k][0]:g} Q{k}={FS_Q[k][1]:g}", directive=True)
    a.text(-128, oy - 72, f".param MMT{k}=1/((2*pi*fs{k})**2*CMT) MAS{k}=(MMT{k}-MMD)/SD**2-MA1 RAS{k}=sqrt(MMT{k}/CMT)/Q{k}/SD**2", directive=True)
    # ---- electrical
    a.text(-128, oy + 8, "ELECTRICAL", size=2)
    for w in ((-96, 80, -128, 80), (-16, 80, -96, 80), (128, 80, 64, 80), (352, 80, 128, 80), (352, 96, 352, 80),
              (-96, 112, -96, 80), (128, 112, 128, 80), (-96, 208, -96, 192), (128, 208, 128, 176), (128, 208, -96, 208),
              (352, 208, 352, 176), (352, 208, 128, 208), (-96, 224, -96, 208)):
        a.w(*w, oy=oy)
    a.flag(-96, 224, "0", oy); a.flag(-128, 80, f"out{k}", oy)
    a.sym("res", -112, 96, "R0", f"R_L{k}", "{RL}", oy)
    a.sym("voltage", -32, 80, "R270", f"Vi{k}", "0", oy, ("0 32 56 VTop 2", "3 -32 56 VBottom 2"))
    a.sym("cap", 112, 112, "R0", f"C_E0_{k}", "{CE0}", oy)
    a.sym("f", 352, 176, "M180", f"F_e{k}", f"Vu{k} {{-E*CE0/x0}}", oy, ("0 24 80 Left 2", "3 24 0 Left 2"))
    # ---- mechanical (impedance analogy)
    X = 160                                            # mechanical block offset
    a.text(432 + X, oy + 8, "MECHANICAL (V = force, I = velocity; Vu = 0 V ammeter, I(Vu) = -u_D)", size=2)
    for w in ((592, 80, 544, 80), (784, 80, 672, 80), (976, 80, 864, 80), (976, 112, 976, 80), (544, 112, 544, 80),
              (544, 208, 544, 176), (656, 208, 544, 208), (976, 208, 976, 192), (976, 208, 736, 208), (544, 224, 544, 208),
              (1024, 128, 1136, 128), (1024, 176, 1136, 176)):
        a.w(w[0] + X, w[1], w[2] + X, w[3], oy=oy)
    a.flag(544 + X, 224, "0", oy); a.flag(1136 + X, 128, f"f{k}", oy); a.flag(1136 + X, 176, f"b{k}", oy)
    a.sym("cap", 528 + X, 112, "R0", f"C_MD{k}", "{CMD}", oy, ("0 -8 8 Right 2", "3 -8 56 Right 2"))
    a.sym("ind", 576 + X, 96, "R270", f"L_MMD{k}", "{MMD}", oy, HL, g.NOLOSS)
    a.sym("res", 880 + X, 64, "R90", f"R_MD{k}", "{RMD}", oy, H_)
    a.sym("e", 976 + X, 96, "M0", f"E_F{k}", "{SD}", oy, ("0 -80 16 Left 2", "3 -80 96 Left 2"))
    a.sym("voltage", 752 + X, 208, "R90", f"Vu{k}", "0", oy, HV)
    # ---- acoustic (impedance analogy): back | diaphragm | front
    a.text(-128, oy + 440, "ACOUSTIC (V = pressure, I = volume velocity)", size=2)
    a.text(-112, oy + 480, "back: C_AB, R_AS, M_AS", size=1)
    a.text(288, oy + 632, "diaphragm: U = S_D u_D", size=1)
    a.text(480, oy + 480, "front: M_A1 + actuator (1 Pa)", size=1)
    for w in ((32, 560, 0, 560), (144, 560, 112, 560), (288, 560, 224, 560), (240, 560, 240, 512), (304, 560, 288, 560),
              (448, 560, 448, 512), (400, 560, 384, 560), (512, 560, 400, 560), (672, 560, 592, 560), (672, 608, 672, 560),
              (0, 608, 0, 560), (0, 752, 0, 672), (672, 752, 672, 688), (672, 752, 0, 752), (0, 784, 0, 752)):
        a.w(*w, oy=oy)
    a.flag(0, 784, "0", oy); a.flag(448, 512, f"f{k}", oy); a.flag(240, 512, f"b{k}", oy)
    a.sym("cap", -16, 608, "R0", f"C_AB{k}", "{CAB}", oy, ("0 -8 8 Right 2", "3 -8 56 Right 2"), spice="Rpar=1e15")
    a.sym("res", 128, 544, "R90", f"R_AS{k}", "{RAS%s}" % k, oy, H_)
    a.sym("ind", 128, 576, "R270", f"L_MAS{k}", "{MAS%s}" % k, oy, HL, g.NOLOSS)
    a.sym("f", 304, 560, "R270", f"F_U{k}", f"Vu{k} {{SD}}", oy, ("0 32 40 VTop 2", "3 -32 40 VBottom 2"))
    a.sym("ind", 496, 576, "R270", f"L_MA1_{k}", "{MA1}", oy, HL, g.NOLOSS)
    a.sym("voltage", 672, 592, "R0", f"V_act{k}", "AC 1", oy)


def build():
    a = Asc()
    a.text(-128, -440, "Lab C - condenser microphones 4133 / 4134 driven by an electrostatic actuator (pressure applied straight to the diaphragm: no sound field, no T(s) / Gpb generator)", size=2)
    a.text(-128, -408, "Layout as in the lectures: electrical loop | mechanical loop, acoustic network below. Only fs and Q are typed in; M_AS and R_AS follow inside LTspice.", size=2)
    a.text(-128, -360, f".param a={P['a']:g} x0={P['x0']:g} E={P['E']:g} MMD={P['MMD']:g} CMD={P['CMD']:g} RMD=1e-9 Vb={P['V']:g} RL={P['RL']:g} rho={RHO} c={C0}", directive=True)
    a.text(-128, -328, ".param SD=pi*a**2 CAB=Vb/(rho*c**2) MA1=0.6133*rho/(pi*a) CMT=1/(1/CMD+SD**2/CAB) CE0=8.854e-12*SD/x0", directive=True)
    a.text(-128, -296, ".ac dec 200 20 60k", directive=True)
    mic(a, 0, "33")
    mic(a, 1040, "34")
    a.text(-128, 1920, "plot V(out33) V(out34): dB re 1 V/Pa and phase. Low-frequency level E*SD*CMT/x0 = 11.1 mV/Pa (-39.1 dB), below the nominal 12.5 mV/Pa: see the brief's appendix.", size=2)
    a.text(-128, 1952, "fs = where the phase is -90 deg,  Q = |H(fs)| / |H(f << fs)| (linear).  R_MD = 0 in the brief (1 nOhm here).", size=2)
    a.dump(HERE / "LabC_CondenserMics.asc")
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
    if "--export" in sys.argv:          # LTspice result as CSV for matlab/part4_model.m
        d = g.run_ltspice(HERE / "LabC_CondenserMics.asc")
        out = HERE.parent / "matlab" / "results" / "ltspice_labC.csv"
        with open(out, "w") as fh:
            fh.write("f_Hz,re_out33,im_out33,re_out34,im_out34\n")
            for fi, a, b in zip(d["frequency"], d["v(out33)"], d["v(out34)"]):
                fh.write(f"{fi.real:.6g},{a.real:.9g},{a.imag:.9g},{b.real:.9g},{b.imag:.9g}\n")
        print(f"wrote {out}")
    if "--verify" in sys.argv:
        sys.exit(0 if verify() else 1)
