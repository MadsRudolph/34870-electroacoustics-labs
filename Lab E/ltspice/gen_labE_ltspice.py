#!/usr/bin/env python3
"""Lab E: LTspice model of the System D woofer (Scan-Speak 26W/8534G00) in its 88 L box
with the vent PLUGGED, as it stands in the anechoic chamber in part 2.

    python3 gen_labE_ltspice.py             # write the two .asc/.plt files, print the predictions
    python3 gen_labE_ltspice.py --verify    # run LTspice headless, compare with the closed form
    python3 gen_labE_ltspice.py --preview   # draw the schematics to preview/*.png

Two parameter sets, one schematic each:
    LabE_Woofer_LabD.asc       T-S parameters measured in Lab D (6-Oct, analyse_labD.m)
    LabE_Woofer_Datasheet.asc  the Scan-Speak data sheet

Same drawing as Problems 7.4 (Leach, lecture 7 slide 27): IMPEDANCE analogy in all three
domains, so every domain is a loop and the couplings are controlled sources.
    electrical: e_g -> R_E -> L_E -> H_emf = Bl*u                      (current i = I(Vd1))
    mechanical: H_Bli = Bl*i -> M_MD -> R_MS -> C_MS -> E = S_D*p_D    (velocity u = I(Vd2))
    acoustical: F = S_D*u flows through the box compliance C_AB (rear) and the front
                radiation impedance Z_ar of a baffled piston, in series.
Mass bookkeeping: the T-S M_MS already contains an air load, so M_MD = M_MS - S_D^2 M_A1
and the circuit's own front air mass puts it back. With that the closed-box resonance is
fs*sqrt(1 + V_AS/V_B), the same relation Lab D used to get V_AS. The air mass inside the
box is neglected.

Outputs for e_g = Vg (default 2.83 V, so V(SPL2pi) compares with the data sheet's 89 dB):
    V(SPL2pi)  far field at distance r on an infinite baffle (half space), as SPL/20u
    V(SPL4pi)  the same driver radiating into full space: 6 dB lower everywhere
    V(SPLbs)   2pi response times a first-order baffle-step shelf for a front of width Wb,
               -6 dB at low frequency, 0 dB high, -3 dB at f = 115/Wb (rule of thumb,
               NOT course material; the real step has diffraction ripples on top)
    V(eg)/I(Vd1) = Z_E, to compare with Lab D's closed-box impedance (fc 42.0 Hz, 123 ohm)
What LTspice cannot do here: the edge diffraction ripples and the off-axis beaming
(2 J1(x)/x is not a rational function). Use diffrac.m and the piston formula for those.
Needs the Lab A builder: ../../Lab A/LTspice/gen_ltspice.py.
"""
import cmath, math, pathlib, sys

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402

g.PINS["h"] = [(0, 16), (0, 96)]
T = 20.0                                     # Lab D assumed 20 C (temperature not recorded)
C0 = 331.3 * math.sqrt(1 + T / 273.15)
RHO = 1.2041 * 293.15 / (273.15 + T)
PREF = 20e-6
VB = 0.435 * 0.45 * 0.45                     # woofer box, inner (labD_dims)
WB = 0.435                                   # front width of the woofer box
RE, LE, D = 5.7, 0.96e-3, 0.211              # R_E measured = data sheet; L_E from the data sheet
R_MIC, VG = 1.0, 2.83                        # set R_MIC to r_mic_2 after the lab


def labd():
    """Lab D results (analyse_labD, 6-Oct): free air fs, Qms, Qes and closed-box fc."""
    fs, fc, Qms, Qes = 22.72, 42.01, 9.95, 0.511
    Sd = math.pi * (D / 2) ** 2
    Vas = VB * ((fc / fs) ** 2 - 1)
    Cms = Vas / (RHO * C0 ** 2) / Sd ** 2
    ws = 2 * math.pi * fs; Mms = 1 / (ws ** 2 * Cms)
    return dict(name="LabD", label="Lab D measurement", Sd=Sd, Cms=Cms, Mms=Mms,
                Bl=math.sqrt(ws * RE * Mms / Qes), Rms=ws * Mms / Qms, Vas=Vas)


def datasheet():
    Sd, Cms = 350e-4, 0.95e-3
    return dict(name="Datasheet", label="Scan-Speak data sheet", Sd=Sd, Cms=Cms, Mms=50.5e-3,
                Bl=10.1, Rms=0.80, Vas=RHO * C0 ** 2 * Sd ** 2 * Cms)


def model(p):
    a = math.sqrt(p["Sd"] / math.pi)
    MA1 = 8 * RHO / (3 * math.pi ** 2 * a)
    m = dict(p, a=a, MA1=MA1, RA1=0.441 * RHO * C0 / p["Sd"], RA2=RHO * C0 / p["Sd"],
             CA1=5.94 * a ** 3 / (RHO * C0 ** 2), CAB=VB / (RHO * C0 ** 2))
    m["Mmd"] = p["Mms"] - p["Sd"] ** 2 * MA1
    return m


def response(m, f):
    w = 2 * math.pi * f; jw = 1j * w
    Zar = 1 / (1 / (jw * m["MA1"]) + 1 / (m["RA2"] + 1 / (1 / m["RA1"] + jw * m["CA1"])))
    ZM = jw * m["Mmd"] + m["Rms"] + 1 / (jw * m["Cms"]) + m["Sd"] ** 2 * (Zar + 1 / (jw * m["CAB"]))
    ZE = RE + jw * LE + m["Bl"] ** 2 / ZM
    i = VG / ZE; u = m["Bl"] * i / ZM; U = m["Sd"] * u
    p2 = jw * RHO * U / (2 * math.pi * R_MIC)
    wb = math.sqrt(2) * 2 * math.pi * 115 / WB
    return dict(ZE=ZE, p2=p2, p4=p2 / 2, pbs=p2 * (jw + wb / 2) / (jw + wb))


def summary(m):
    fc = (1 / (2 * math.pi)) / math.sqrt(m["Mms"] * m["Cms"] / (1 + m["Vas"] / VB))
    wc = 2 * math.pi * fc
    Cmc = 1 / (1 / m["Cms"] + m["Sd"] ** 2 / m["CAB"])
    Qec = RE * wc * m["Mms"] / m["Bl"] ** 2; Qmc = wc * m["Mms"] / m["Rms"]
    Qtc = 1 / (1 / Qec + 1 / Qmc)
    p1 = RHO * m["Bl"] * m["Sd"] / (2 * math.pi * RE * m["Mms"])          # Pa at 1 m for 1 V, mid band, 2pi
    zpk = max(abs(response(m, fc * (0.9 + k * 1e-4))["ZE"]) for k in range(2001))   # radiation R adds to R_MS
    return dict(fc=fc, Qtc=Qtc, Qec=Qec, Zmax=zpk, Cmc=Cmc,
                spl=20 * math.log10(VG * p1 / R_MIC / PREF), ka1=C0 / (2 * math.pi * m["a"]))


def build(m):
    name = f"LabE_Woofer_{m['name']}"
    s = g.Sch()
    s.text(0, -480, f"Lab E part 2 - System D woofer (Scan-Speak 26W/8534G00) in its {VB*1e3:.1f} L box, vent PLUGGED.  Parameters: {m['label']}.")
    s.text(0, -448, "IMPEDANCE analogy in all three domains: electrical V = voltage, I = current | mechanical V = force, I = velocity | acoustical V = pressure, I = volume velocity")
    s.text(0, -400, f".param Vg={VG} r={R_MIC} Wb={WB} Re={RE} Le={LE:g} Bl={m['Bl']:.4g} Mmd={m['Mmd']:.5g} Rms={m['Rms']:.4g} Cms={m['Cms']:.5g} Sd={m['Sd']:.5g}", directive=True)
    s.text(0, -368, f".param MA1={m['MA1']:.5g} RA1={m['RA1']:.5g} RA2={m['RA2']:.5g} CA1={m['CA1']:.5g} CAB={m['CAB']:.5g} rho={RHO:.4f}", directive=True)
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
    # ---- acoustical: U = Sd*u through the box (rear) and the front radiation impedance in series
    ay = 480
    s.text(0, ay - 128, "acoustic load: box compliance C_AB (rear, vent plugged) in series with the front radiation impedance Z_ar (baffled piston)")
    s.text(0, ay - 96, "V(pD) = (Z_ar + 1/(s C_AB)) U drives the reaction force;  V(pF) = Z_ar U is the pressure on the front of the cone")
    s.f_inject(128, ay, "F_SdUd", "Vd2", "{Sd}")
    s.flag(192, ay, "pD"); s.wire(128, ay, 256, ay)
    x = s.hser("cap", 256, ay, "C_AB", "{CAB}"); s.wire(x, ay, x + 96, ay)
    s.flag(x + 48, ay, "pF")
    s.vshunt("ind", x + 96, ay, "L_MA1", "{MA1}", g.NOLOSS)
    s.wire(x + 96, ay, x + 96 + g.PITCH, ay)
    s.radnet(x + 96 + g.PITCH, ay, ("R_RA2", "{RA2}"), ("R_RA1", "{RA1}"), ("C_CA1", "{CA1}"))
    # ---- outputs
    oy, ox = ay, 1440
    s.text(ox - 96, oy - 176, "outputs (plot in dB, they read directly as dB SPL at distance r for e_g = Vg)")
    s.sym("h", "R0", ox, oy - 16, "H_u", "Vd2 1", win=["WINDOW 0 24 40 Left 2", "WINDOW 3 24 72 Left 2"]); s.gnd(ox, oy + 80); s.flag(ox, oy, "uD")
    s.e_src(ox + 400, oy, "E_2pi", "Laplace=k2pi*s", "uD"); s.flag(ox + 400, oy, "SPL2pi")
    s.e_src(ox + 880, oy, "E_4pi", "0.5", "SPL2pi"); s.flag(ox + 880, oy, "SPL4pi")
    s.e_src(ox + 1280, oy, "E_bs", "Laplace=(s+wst/2)/(s+wst)", "SPL2pi"); s.flag(ox + 1280, oy, "SPLbs")
    s.text(0, 880, ".param wst={sqrt(2)*2*pi*115/Wb} k2pi={rho*Sd/(2*pi*r*20u)}", directive=True)
    s.text(0, 912, ".ac dec 200 10 20k", directive=True)
    s.text(0, 960, "SPL2pi: p = j*w*rho*Sd*u/(2 pi r) (half space, infinite baffle, = the data sheet condition).  SPL4pi = 6 dB lower (full space, what a small box does at low f).")
    s.text(0, 992, "SPLbs: SPL2pi x (s + wst/2)/(s + wst): first-order baffle step, -3 dB at 115/Wb Hz. Rule of thumb only; the measured curve adds edge-diffraction ripples on top.")
    t = summary(m)
    s.text(0, 1040, f"check: |Z_E| peak {t['Zmax']:.0f} ohm (radiation resistance adds to R_MS) at f_c = {t['fc']:.1f} Hz (Lab D measured 123 ohm at 42.0 Hz), Q_tc = {t['Qtc']:.2f};  "
           f"mid-band V(SPL2pi) = {t['spl']:.1f} dB at {VG} V, {R_MIC:g} m (data sheet 89 dB);  ka = 1 at {t['ka1']:.0f} Hz")
    s.text(0, 1072, "In the chamber ignore everything below ~125 Hz.  Not in this model: off-axis beaming (2 J1(ka sin th)/(ka sin th)) and the diffraction ripples (diffrac.m).")
    s.dump(HERE / f"{name}.asc")
    g.plt(HERE / f"{name}.plt", [(["V(SPL2pi)", "V(SPL4pi)", "V(SPLbs)"], (1, 1e6)), (["V(eg)/I(Vd1)"], (1, 200))], (10, 20000))
    return HERE / f"{name}.asc"


def verify(files):
    ok = True
    for m, asc in files:
        d = g.run_ltspice(asc); f = [v.real for v in d["frequency"]]
        worst = 0
        for j, fi in enumerate(f):
            r = response(m, fi)
            for got, want in ((d["v(eg)"][j] / d["i(vd1)"][j], r["ZE"]), (d["v(spl2pi)"][j] * PREF, r["p2"]),
                              (d["v(spl4pi)"][j] * PREF, r["p4"]), (d["v(splbs)"][j] * PREF, r["pbs"])):
                worst = max(worst, abs(got / want - 1))
        z = [abs(d["v(eg)"][j] / d["i(vd1)"][j]) for j in range(len(f))]
        jp = max((j for j in range(len(f)) if f[j] < 200), key=lambda j: z[j])
        at = lambda fx: min(range(len(f)), key=lambda j: abs(f[j] - fx))
        spl = lambda k, fx: 20 * math.log10(abs(d[k][at(fx)]))
        good = worst < 2e-3; ok &= good
        print(f"  {'OK ' if good else 'BAD'} {asc.name}: worst deviation {worst:.1e}; |Z_E| peak {z[jp]:.1f} ohm at {f[jp]:.1f} Hz; "
              f"SPL2pi 100/300/1k Hz = {spl('v(spl2pi)',100):.1f}/{spl('v(spl2pi)',300):.1f}/{spl('v(spl2pi)',1000):.1f} dB; "
              f"SPLbs 100/300/1k = {spl('v(splbs)',100):.1f}/{spl('v(splbs)',300):.1f}/{spl('v(splbs)',1000):.1f} dB")
    print("ALL OK" if ok else "MISMATCH")
    return ok


if __name__ == "__main__":
    files = []
    print(f"air: T = {T} C, c = {C0:.1f} m/s, rho = {RHO:.4f} kg/m3;  V_B = {VB*1e3:.2f} L, vent plugged;  r = {R_MIC} m, e_g = {VG} V")
    print(f"baffle step (rule of thumb): front width {WB} m -> -3 dB point at 115/W = {115/WB:.0f} Hz")
    for p in (labd(), datasheet()):
        m = model(p); t = summary(m)
        print(f"{p['label']:22s} M_MS {p['Mms']*1e3:5.1f} g  C_MS {p['Cms']*1e3:.3f} mm/N  Bl {p['Bl']:.2f} Tm  R_MS {p['Rms']:.2f} kg/s  "
              f"V_AS {p['Vas']*1e3:5.1f} L  M_MD {m['Mmd']*1e3:.1f} g -> f_c {t['fc']:.1f} Hz  Q_tc {t['Qtc']:.3f}  "
              f"|Z|max {t['Zmax']:.0f} ohm  SPL(2pi, mid band) {t['spl']:.1f} dB  ka=1 at {t['ka1']:.0f} Hz")
        files.append((m, build(m)))
    if "--preview" in sys.argv:
        import preview_asc as pv
        pv.HERE = HERE
        [pv.main(str(a)) for _, a in files]
    if "--verify" in sys.argv:
        sys.exit(0 if verify(files) else 1)
