#!/usr/bin/env python3
"""Generate the Lab A circuits as LTspice schematics (.asc) with plot settings (.plt),
and optionally verify them by running LTspice headless and comparing the key
numbers with the KiCad/ngspice runthrough.

    python3 gen_ltspice.py            # write the .asc / .plt files next to this script
    python3 gen_ltspice.py --verify   # also netlist + batch-run in LTspice and check numbers

Conventions (same as the runthrough): mechanical side in the MOBILITY analogy
(velocity = node voltage, force = current, mass = C to ground, compliance = L,
damper R_M = resistor 1/R_M), acoustic side in the IMPEDANCE analogy (pressure =
node voltage, volume velocity = current, M_A = L, C_A = C to ground, R_A = R).
A 1 A source is 1 N (or 1 m3/s), so node voltages read directly as m/s per N.
"""
import math, os, struct, subprocess, sys, pathlib

HERE = pathlib.Path(__file__).resolve().parent
RHO, C0 = 1.18, 344.0

PINS = {"res": [(16, 16), (16, 96)], "ind": [(16, 16), (16, 96)], "cap": [(16, 0), (16, 64)],
        "voltage": [(0, 16), (0, 96)], "current": [(0, 0), (0, 80)], "f": [(0, 0), (0, 80)],
        "g": [(0, 96), (0, 16), (-48, 32), (-48, 80)], "e": [(0, 16), (0, 96), (-48, 32), (-48, 80)]}
ROT = {"R0": lambda x, y: (x, y), "R90": lambda x, y: (-y, x), "R180": lambda x, y: (-x, -y), "R270": lambda x, y: (y, -x)}
WIN = {("res", "R90"): ["WINDOW 0 0 56 VBottom 2", "WINDOW 3 32 56 VTop 2"],
       ("ind", "R90"): ["WINDOW 0 5 56 VBottom 2", "WINDOW 3 32 56 VTop 2"],
       ("voltage", "R270"): ["WINDOW 0 32 56 VTop 2", "WINDOW 3 -32 56 VBottom 2"]}


class Sch:
    def __init__(self):
        self.wires, self.flags, self.syms, self.texts = [], [], [], []

    def wire(self, x1, y1, x2, y2):
        if (x1, y1) != (x2, y2):
            self.wires.append(f"WIRE {x1} {y1} {x2} {y2}")

    def flag(self, x, y, name):
        self.flags.append(f"FLAG {x} {y} {name}")

    def gnd(self, x, y):
        self.flag(x, y, "0")

    def sym(self, kind, rot, ox, oy, name, value, value2=None, spiceline=None):
        lines = [f"SYMBOL {kind} {ox} {oy} {rot}"] + WIN.get((kind, rot), [])
        lines.append(f"SYMATTR InstName {name}")
        lines.append(f"SYMATTR Value {value}")
        if value2:
            lines.append(f"SYMATTR Value2 {value2}")
        if spiceline:
            lines.append(f"SYMATTR SpiceLine {spiceline}")
        self.syms.append("\n".join(lines))
        r = ROT[rot]
        return [(ox + r(*p)[0], oy + r(*p)[1]) for p in PINS[kind]]

    def text(self, x, y, txt, directive=False, size=2):
        txt = txt.replace("\n", "\\n")        # .asc keeps multi-line text on one line with a literal \n
        self.texts.append(f"TEXT {x} {y} Left {size} {'!' if directive else ';'}{txt}")

    # ---- helpers: x, y is always the pin that sits on the rail -------------
    def vshunt(self, kind, x, y, name, value, spiceline=None):
        """vertical element from the rail node (x, y) down to ground"""
        oy = y - 16 if kind in ("res", "ind") else y
        pins = self.sym(kind, "R0", x - 16, oy, name, value, spiceline=spiceline)
        self.gnd(*pins[1])
        return pins

    def vert(self, kind, x, y, name, value, spiceline=None):
        """vertical element from (x, y) down, bottom pin returned (not grounded)"""
        oy = y - 16 if kind in ("res", "ind") else y
        return self.sym(kind, "R0", x - 16, oy, name, value, spiceline=spiceline)[1]

    def hser(self, kind, xl, y, name, value, spiceline=None):
        """horizontal element starting at (xl, y); returns the x of its right end"""
        length = 64 if kind == "cap" else 80
        self.sym(kind, "R90", xl + length + 16, y - 16, name, value, spiceline=spiceline)
        return xl + length

    def vsense(self, xl, y, name):
        """0 V source, + on the left so I(name) is the flow left -> right"""
        self.sym("voltage", "R270", xl - 16, y, name, "0")
        return xl + 80

    def isrc(self, x, y, name, ac="AC 1"):
        """current source injecting into the node (x, y) from ground"""
        self.sym("current", "R180", x, y + 80, name, "0", value2=ac)
        self.gnd(x, y + 80)

    def vsrc(self, x, y, name, ac="AC 1"):
        pins = self.sym("voltage", "R0", x, y - 16, name, "0", value2=ac)
        self.gnd(*pins[1])

    def g_inject(self, x, y, name, gain, ctrl):
        """VCCS pushing gain*V(ctrl) INTO the node (x, y)"""
        pins = self.sym("g", "R0", x, y - 16, name, gain)
        self.gnd(*pins[0]); self.flag(*pins[2], ctrl); self.gnd(*pins[3])

    def g_draw(self, x, y, name, gain, ctrl):
        """VCCS drawing gain*V(ctrl) OUT of the node (x, y) to ground (reaction force)"""
        pins = self.sym("g", "R180", x, y + 96, name, gain)
        self.gnd(*pins[1]); self.flag(*pins[2], ctrl); self.gnd(*pins[3])

    def e_src(self, x, y, name, gain, ctrl):
        pins = self.sym("e", "R0", x, y - 16, name, gain)
        self.gnd(*pins[1]); self.flag(*pins[2], ctrl); self.gnd(*pins[3])

    def f_inject(self, x, y, name, vsense, gain):
        self.sym("f", "R180", x, y + 80, name, f"{vsense} {gain}")
        self.gnd(x, y + 80)

    def dump(self, path):
        body = ["Version 4", "SHEET 1 3000 1600"] + self.wires + self.flags + self.syms + self.texts
        pathlib.Path(path).write_text("\n".join(body) + "\n")


def plt(path, panes, xr):
    """panes: list of (traces, (ymin, ymax)). Bode panes with magnitude in dB + phase."""
    out = ["[AC Analysis]", "{", f"   Npanes: {len(panes)}"]
    cid = 524290
    for traces, (ylo, yhi) in panes:
        out.append("   {")
        items = []
        for t in traces:
            items.append('{%d,0,"%s"}' % (cid, t)); cid += 1
        out.append(f"      traces: {len(traces)} " + " ".join(items))
        out.append(f"      X: (' ',0,{xr[0]},0,{xr[1]})")
        out.append(f"      Y[0]: (' ',0,{ylo:g},20,{yhi:g})")
        out.append("      Y[1]: (' ',0,-180,45,180)")
        out.append("      Log: 1 2 0")
        out.append("      GridStyle: 1")
        out.append("      PltMag: 1")
        out.append("      PltPhi: 1 0")
        out.append("   }")
    out.append("}")
    pathlib.Path(path).write_text("\r\n".join(out) + "\r\n")


NOLOSS = "Rser=0"


# =====================================================================  Part 1 / 3
def mech(s, ox, oy, sfx, link, with_g=False, S=("60e-4", "210e-4")):
    """dual-diaphragm mechanical network, mobility analogy. link = 'st' | 'so'."""
    gap = 144 if with_g else 0
    s.isrc(ox, oy, f"I_F{sfx}")
    xl = ox + 416 + gap                                  # left end of the link
    s.wire(ox, oy, xl, oy)
    s.flag(ox + 48, oy, f"u_vc{sfx}")
    s.vshunt("cap", ox + 112, oy, f"C_Mmvc{sfx}", "{Mmvc}")
    s.vshunt("ind", ox + 224, oy, f"L_Cmsp{sfx}", "{Cmsp}", NOLOSS)
    s.vshunt("res", ox + 336, oy, f"R_Rmsp{sfx}", "{1/Rmsp}")
    if with_g:
        s.g_draw(ox + 464, oy, f"G_mi{sfx}", "{Si}", f"p_i{sfx}")
    xr = s.hser("ind", xl, oy, f"L_Cmd{sfx}", "{Cmd_%s}" % link, "Rser=1u")
    s.hser("res", xl, oy - 96, f"R_Rmd{sfx}", "{1/Rmd_%s}" % link)
    s.wire(xl, oy, xl, oy - 96); s.wire(xr, oy, xr, oy - 96)
    end = xr + 320 + gap
    s.wire(xr, oy, end, oy)
    s.flag(xr + 48, oy, f"u_d{sfx}")
    s.vshunt("cap", xr + 96, oy, f"C_Mmd{sfx}", "{Mmd}")
    s.vshunt("ind", xr + 208, oy, f"L_Cmsr{sfx}", "{Cmsr}", NOLOSS)
    s.vshunt("res", xr + 320, oy, f"R_Rmsr{sfx}", "{1/Rmsr}")
    if with_g:
        s.g_draw(end, oy, f"G_mo{sfx}", "{So}", f"p_o{sfx}")
    return end


def acoustic(s, ax, ay, tag, sfx, ctrl, Sname):
    """radiation impedance of a baffled piston, BOTH faces in series (every Z x2)"""
    s.g_inject(ax + 64, ay, f"G_a{tag}{sfx}", "{%s}" % Sname, ctrl)
    s.wire(ax + 64, ay, ax + 352, ay)
    s.flag(ax + 112, ay, f"p_{tag}{sfx}")
    s.vshunt("ind", ax + 208, ay, f"L_2MA1{tag}{sfx}", "{2*MA1%s}" % tag, NOLOSS)
    mid = s.vert("res", ax + 352, ay, f"R_2RA2{tag}{sfx}", "{2*RA2%s}" % tag)
    s.wire(mid[0], mid[1], mid[0], mid[1] + 16)
    s.wire(mid[0] - 64, mid[1] + 16, mid[0] + 64, mid[1] + 16)
    s.vshunt("res", mid[0] - 64, mid[1] + 16, f"R_2RA1{tag}{sfx}", "{2*RA1%s}" % tag)
    s.vshunt("cap", mid[0] + 64, mid[1] + 16, f"C_CA1h{tag}{sfx}", "{CA1%s/2}" % tag)


P1_PARAMS = (".param Mmvc=6m Cmsp=1.3m Rmsp=0.5 Mmd=5m Cmsr=2.7m Rmsr=0.22\n"
             ".param Cmd_st=1e-10 Rmd_st=5000 Cmd_so=3e-6 Rmd_so=5")


def part1():
    s = Sch()
    s.text(0, -220, "Lab A part 1 - dual-diaphragm loudspeaker, MOBILITY analogy: node voltage = velocity [m/s], current = force [N]")
    s.text(0, -188, "mass -> C to ground, compliance -> L, damper R_M -> resistor 1/R_M.  I = 1 A means F = 1 N")
    s.text(0, -140, "STIFF link: Cmd = 1e-10 m/N, Rmd = 5000 Ns/m")
    mech(s, 0, 0, "_st", "st")
    s.text(0, 260, "SOFT link: Cmd = 3e-6 m/N, Rmd = 5 Ns/m")
    mech(s, 0, 400, "_so", "so")
    s.text(0, 600, P1_PARAMS, directive=True)
    s.text(0, 670, ".ac dec 200 10 10k", directive=True)
    s.text(0, 720, "1a: plot V(u_vc_st) V(u_d_st) V(u_vc_so) V(u_d_so).   1b: Z_M = F/u = 1/V(u_vc_st) and 1/V(u_vc_so)  (Add Traces, type the expression)")
    s.dump(HERE / "Part1_DualDiaphragm.asc")
    plt(HERE / "Part1_DualDiaphragm.plt",
        [(["V(u_vc_st)", "V(u_d_st)", "V(u_vc_so)", "V(u_d_so)"], (1e-5, 10)),
         (["1/V(u_vc_st)", "1/V(u_vc_so)"], (0.1, 1000))], (10, 10000))


def rad_params():
    out = []
    for tag, S in (("i", 60e-4), ("o", 210e-4)):
        a = math.sqrt(S / math.pi)
        out.append(f".param MA1{tag}={8*RHO/(3*math.pi**2*a):.5g} RA1{tag}={0.441*RHO*C0/S:.6g} RA2{tag}={RHO*C0/S:.6g} CA1{tag}={5.94*a**3/(RHO*C0**2):.5g}")
    return "\n".join(out)


def part3(link, title):
    s = Sch()
    s.text(0, -220, f"Lab A part 3 - {title} link, WITH the air load: baffled-piston radiation impedance on BOTH faces of each cone")
    s.text(0, -188, "coupling per cone: G_a injects U = S*u into the acoustic node, G_m draws the reaction force f = S*p from the velocity node")
    end = mech(s, 0, 0, "", link, with_g=True)
    s.text(0, 230, "acoustic side, IMPEDANCE analogy: node voltage = pressure [Pa] (sum of both faces), current = volume velocity [m3/s]")
    acoustic(s, 0, 380, "i", "", "u_vc", "Si")
    acoustic(s, 720, 380, "o", "", "u_d", "So")
    s.text(0, 700, "reference: the same speaker WITHOUT air (part 1), for the overlay")
    mech(s, 0, 840, "_ref", link)
    s.text(0, 1040, P1_PARAMS + "\n.param Si=60e-4 So=210e-4\n" + rad_params(), directive=True)
    s.text(0, 1180, ".ac dec 200 10 10k", directive=True)
    s.text(0, 1230, "3a: V(u_vc) V(u_d) vs V(u_vc_ref) V(u_d_ref);  Z_M = 1/V(u_vc).   3b: front pressure = V(p_i)/2 and V(p_o)/2;")
    s.text(0, 1262, "far field 1 m, half space: 2*pi*frequency*1.18*(60e-4*V(u_vc)+210e-4*V(u_d))/(2*pi*1)")
    name = f"Part3_Coupled_{title}"
    s.dump(HERE / f"{name}.asc")
    plt(HERE / f"{name}.plt",
        [(["V(u_vc)", "V(u_d)", "V(u_vc_ref)", "V(u_d_ref)"], (1e-5, 10)),
         (["1/V(u_vc)", "1/V(u_vc_ref)"], (0.1, 1000)),
         (["V(p_i)/2", "V(p_o)/2", "2*pi*frequency*1.18*(60e-4*V(u_vc)+210e-4*V(u_d))/(2*pi*1)"], (1e-2, 100))], (10, 10000))


# =====================================================================  Part 2
def part2(kind):
    a = 2e-3; S = math.pi * a * a
    L = {1: 25e-3, 3: 80e-3, 5: 100e-3, 7: 40e-3 if kind != "rad" else 38.77e-3}
    V = {2: math.pi * 0.010**2 * 0.050, 4: math.pi * 0.020**2 * 0.080, 6: math.pi * 0.015**2 * 0.060}
    s = Sch()
    title = {"p": "2a - driven by a PRESSURE source (1 Pa)", "U": "2b/2c - driven by a VOLUME-VELOCITY source (1 m3/s)", "rad": "2d/2e - volume-velocity source, tube-end RADIATION impedance at the outlet"}[kind]
    s.text(0, -200, f"Lab A part {title}")
    s.text(0, -168, "IMPEDANCE analogy: node voltage = pressure [Pa], current = volume velocity [m3/s]. Narrow pipes = R_A + M_A in series, chambers = C_A to GROUND")
    s.text(0, -136, "Vs1..Vs7 are 0 V sense sources: I(Vs7) is the volume velocity in the outlet pipe")
    oy = 0
    if kind == "p":
        s.vsrc(0, oy, "V_pin")
    else:
        s.isrc(0, oy, "I_Uin")
    s.flag(0, oy, "p_in")
    x = 0
    s.wire(x, oy, x + 48, oy); x += 48
    for k in (1, 3, 5, 7):
        x2 = s.vsense(x, oy, f"Vs{k}"); s.wire(x2, oy, x2 + 16, oy)
        x3 = s.hser("res", x2 + 16, oy, f"R_RA{k}", "{RA}"); s.wire(x3, oy, x3 + 16, oy)
        x4 = s.hser("ind", x3 + 16, oy, f"L_MA{k}", "{MA%d}" % k, NOLOSS)
        node = x4 + 48
        s.wire(x4, oy, node + (48 if k < 7 else 0), oy)
        if k < 7:
            s.vshunt("cap", node, oy, f"C_CA{k+1}", "{CA%d}" % (k + 1))
            s.flag(node, oy - 0, f"p{k+1}")
            x = node + 48
        else:
            s.flag(node, oy, "p_out")
            if kind == "rad":
                s.wire(node, oy, node + 208, oy)
                s.vshunt("ind", node + 64, oy, "L_MArad", "{MArad}", NOLOSS)
                mid = s.vert("res", node + 208, oy, "R_RA2rad", "{RA2rad}")
                s.wire(mid[0], mid[1], mid[0], mid[1] + 16)
                s.wire(mid[0] - 64, mid[1] + 16, mid[0] + 64, mid[1] + 16)
                s.vshunt("res", mid[0] - 64, mid[1] + 16, "R_RA1rad", "{RA1rad}")
                s.vshunt("cap", mid[0] + 64, mid[1] + 16, "C_CArad", "{CArad}")
            else:
                s.wire(node, oy, node, oy + 48); s.gnd(node, oy + 48)
    p = [".param RA=25k " + " ".join(f"MA{k}={RHO*L[k]/S:.5g}" for k in (1, 3, 5, 7)),
         ".param " + " ".join(f"CA{k}={V[k]/(RHO*C0**2):.5g}" for k in (2, 4, 6))]
    if kind == "rad":
        p.append(f".param MArad={0.6133*RHO/(math.pi*a):.5g} CArad={0.55*math.pi**2*a**3/(RHO*C0**2):.5g} RA1rad={0.5045*RHO*C0/S:.6g} RA2rad={RHO*C0/S:.6g}")
    s.text(0, 240, "\n".join(p), directive=True)
    s.text(0, 240 + 40 * len(p), ".ac dec 2000 10 1k", directive=True)   # the ladder has Q > 100: a coarse sweep clips the peaks
    y = 300 + 40 * len(p)
    if kind == "p":
        s.text(0, y, "2a: plot I(Vs7) in dB - peaks -98.8/-112.1/-141.6 dB at 77/180/356 Hz = the MINIMA of Z_in. Z_in = V(p_in)/I(Vs1)")
        name = "Part2a_Silencer_PressureSource"; panes = [(["I(Vs7)"], (1e-14, 1e-4)), (["V(p_in)/I(Vs1)"], (1e4, 1e9))]
    elif kind == "U":
        s.text(0, y, "2b: plot I(Vs7) (= U_out/U_in, 0 dB at low f, peaks +38.6/+40.9/+41.1 dB at 47/176/191 Hz = MAXIMA of Z_in).  2c: I(Vs1) I(Vs3) I(Vs5) I(Vs7)")
        name = "Part2bc_Silencer_VolumeVelocitySource"; panes = [(["I(Vs1)", "I(Vs3)", "I(Vs5)", "I(Vs7)"], (1e-6, 100)), (["V(p_in)/I(Vs1)"], (1e4, 1e9))]
    else:
        s.text(0, y, "2d: plot V(p_out) (~ w*MArad*I(Vs7): pipe 7 shortened to 38.77 mm because the effective length already holds the end correction)")
        s.text(0, y + 32, "2e: SPL at 10 m (dB of this expression = dB re 20 uPa): 2*pi*frequency*1.18*I(Vs7)/(4*pi*10)/20e-6")
        name = "Part2de_Silencer_Radiation"; panes = [(["V(p_out)"], (1e-2, 1e6)), (["2*pi*frequency*1.18*I(Vs7)/(4*pi*10)/20e-6"], (1, 1e7))]
    s.dump(HERE / f"{name}.asc")
    plt(HERE / f"{name}.plt", panes, (10, 1000))


# =====================================================================  Part 4
def part4():
    s = Sch()
    s.text(0, -220, "Lab A part 4 - voice coil driving two masses. Electrical loop (left) + mechanical MOBILITY network (right)")
    s.text(0, -188, "coupling: E_emf = Bl*u_c opposes the drive (back-EMF), F_Bl injects the Lorentz force f = Bl*i = 1.5*I(Vs1) into node u_c")
    oy = 0
    s.vsrc(0, oy, "V1")
    s.flag(0, oy, "vin")
    s.wire(0, oy, 48, oy)
    x = s.vsense(48, oy, "Vs1"); s.wire(x, oy, x + 16, oy)
    x = s.hser("res", x + 16, oy, "R_Rc", "{Rc}"); s.wire(x, oy, x + 16, oy)
    x = s.hser("ind", x + 16, oy, "L_Le", "{Le}", NOLOSS)
    s.wire(x, oy, x + 96, oy)
    s.e_src(x + 96, oy, "E_emf", "{Bl}", "u_c")
    mx = x + 96 + 240
    s.f_inject(mx, oy, "F_Bl", "Vs1", "{Bl}")
    s.wire(mx, oy, mx + 224, oy)
    s.flag(mx + 48, oy, "u_c")
    s.vshunt("cap", mx + 128, oy, "C_Mmc", "{Mmc}")
    xl = mx + 224
    xr = s.hser("ind", xl, oy, "L_Cms", "{Cms}", "Rser=1u")
    s.hser("res", xl, oy - 96, "R_Rms", "{1/Rms}")
    s.wire(xl, oy, xl, oy - 96); s.wire(xr, oy, xr, oy - 96)
    s.wire(xr, oy, xr + 320, oy)
    s.flag(xr + 48, oy, "u_1")
    s.vshunt("cap", xr + 96, oy, "C_Mm1", "{Mm1}")
    s.vshunt("ind", xr + 208, oy, "L_Cms2", "{Cms2}", NOLOSS)
    s.vshunt("res", xr + 320, oy, "R_Rms2", "{1/Rms2}")
    s.text(0, 240, ".param Rc=0.5 Le=10u Bl=1.5 Mmc=5m Cms=1e-5 Rms=1 Mm1=100m Cms2=1e-2 Rms2=0.1", directive=True)
    s.text(0, 280, ".ac dec 200 1 10k", directive=True)
    s.text(0, 330, "4a: V(u_c) V(u_1) [m/s per V].  4b: Z_M = Bl*i/u_c = 1.5*I(Vs1)/V(u_c).  4c: Z_E = V(vin)/I(Vs1)")
    s.text(0, 362, "sign check: the 4.9 Hz peak of V(u_c) must be SMALL (0.65). If it is ~30, the back-EMF has the wrong sign.")
    s.dump(HERE / "Part4_Coil_Electromechanical.asc")
    plt(HERE / "Part4_Coil_Electromechanical.plt",
        [(["V(u_c)", "V(u_1)"], (1e-7, 10)), (["1.5*I(Vs1)/V(u_c)"], (0.01, 1e5)), (["V(vin)/I(Vs1)"], (0.1, 100))], (1, 10000))


# =====================================================================  verify
def run_ltspice(asc):
    """LTspice's own command-line parser chokes on spaces, so run a copy in a space-free temp dir."""
    import shutil, tempfile
    env = dict(os.environ, WINEARCH="win64", WINEPREFIX=os.path.expanduser("~/.local/share/wineprefixes/ltspice"), WINEDEBUG="-all")
    exe = "/usr/share/ltspice/LTspice.exe"
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="ltlabA_"))
    work = tmp / asc.name; shutil.copy(asc, work)
    wp = lambda q: subprocess.run(["winepath", "-w", str(q)], env=env, capture_output=True, text=True).stdout.strip()
    subprocess.run(["wine", exe, "-netlist", wp(work)], env=env, capture_output=True, timeout=120)
    net = work.with_suffix(".net")
    if not net.exists():
        raise SystemExit(f"netlisting failed for {asc.name}")
    subprocess.run(["wine", exe, "-b", wp(net)], env=env, capture_output=True, timeout=300)
    raw = work.with_suffix(".raw")
    if not raw.exists():
        log = work.with_suffix(".log")
        raise SystemExit(f"simulation failed for {asc.name}:\n" + (log.read_bytes().decode("utf-16le", "ignore") if log.exists() else "no log"))
    cols = read_raw(raw); cols["_net"] = net.read_text(errors="ignore")
    shutil.rmtree(tmp, ignore_errors=True)
    return cols


def read_raw(path):
    b = path.read_bytes(); key = "Binary:\n".encode("utf-16le"); i = b.find(key)
    head = b[:i].decode("utf-16le"); data = b[i + len(key):]
    names = []; invars = False; npts = 0
    for ln in head.splitlines():
        if ln.startswith("No. Points:"): npts = int(ln.split(":")[1])
        if ln.startswith("Variables:"): invars = True; continue
        if invars and ln.strip(): names.append(ln.split()[1].lower())
    nv = len(names); vals = struct.unpack(f"<{npts*nv*2}d", data[:npts * nv * 16])
    cols = {n: [] for n in names}
    for p in range(npts):
        for v, n in enumerate(names):
            k = 2 * (p * nv + v); cols[n].append(complex(vals[k], vals[k + 1]))
    return cols


def feat(f, y, lo, hi, kind="max"):
    idx = [i for i, x in enumerate(f) if lo <= x.real <= hi]
    j = (max if kind == "max" else min)(idx, key=lambda i: abs(y[i]))
    return f[j].real, abs(y[j])


def verify():
    ok = True
    def chk(label, got, want, tol=0.03):
        nonlocal ok
        good = abs(got - want) <= tol * abs(want); ok &= good
        print(f"  {'OK ' if good else 'BAD'} {label}: {got:.4g} (expected {want:.4g})")
    d = run_ltspice(HERE / "Part1_DualDiaphragm.asc"); f = d["frequency"]
    print("Part 1"); fr, a = feat(f, d["v(u_vc_st)"], 20, 200); chk("stiff resonance Hz", fr, 51.3); chk("stiff peak m/s/N", a, 1.389)
    fr, a = feat(f, d["v(u_vc_so)"], 600, 1600, "min"); chk("soft dip Hz", fr, 1288); chk("soft |Z_M| max", 1 / a, 334, 0.06)
    fr, a = feat(f, d["v(u_vc_so)"], 1500, 3000); chk("soft 2nd resonance Hz", fr, 1799)
    for link, exp in (("Stiff", (43.7, 1.314)), ("Soft", (43.7, 1.314))):
        d = run_ltspice(HERE / f"Part3_Coupled_{link}.asc"); f = d["frequency"]
        print("Part 3", link); fr, a = feat(f, d["v(u_vc)"], 20, 200); chk("resonance with air Hz", fr, exp[0]); chk("peak", a, exp[1])
        fr, a = feat(f, d["v(u_vc_ref)"], 20, 200); chk("reference resonance Hz", fr, 51.3)
        if link == "Soft":
            fr, a = feat(f, d["v(u_vc)"], 600, 1500, "min"); chk("dip with air Hz", fr, 1023); chk("|Z_M| max with air", 1 / a, 129, 0.08)
        else:
            z = 1 / d["v(u_vc)"][-1]; chk("Re Z_M at 10 kHz", z.real, 22.8, 0.05)
    d = run_ltspice(HERE / "Part2a_Silencer_PressureSource.asc"); f = d["frequency"]
    print("Part 2a"); fr, a = feat(f, d["i(vs7)"], 60, 100); chk("peak Hz", fr, 77.1); chk("peak dB", 20 * math.log10(a), -98.8, 0.01)
    fr, a = feat(f, d["i(vs7)"], 300, 400); chk("3rd peak Hz", fr, 356.5); chk("3rd peak dB", 20 * math.log10(a), -141.6, 0.01)
    d = run_ltspice(HERE / "Part2bc_Silencer_VolumeVelocitySource.asc"); f = d["frequency"]
    print("Part 2b"); fr, a = feat(f, d["i(vs7)"], 30, 70); chk("peak Hz", fr, 47.3); chk("peak dB (ideal source, no leak resistor)", 20 * math.log10(a), 38.6, 0.03)
    fr, a = feat(f, d["i(vs7)"], 165, 183); chk("2nd peak Hz", fr, 175.6); chk("2nd peak dB", 20 * math.log10(a), 40.9, 0.03)
    fr, a = feat(f, d["i(vs7)"], 185, 200); chk("3rd peak Hz", fr, 190.8); chk("3rd peak dB", 20 * math.log10(a), 41.1, 0.03)
    chk("1 kHz dB", 20 * math.log10(abs(d["i(vs7)"][-1])), -111.5, 0.01)
    d = run_ltspice(HERE / "Part2de_Silencer_Radiation.asc"); f = d["frequency"]
    print("Part 2d"); chk("p_open at 1 kHz dB", 20 * math.log10(abs(d["v(p_out)"][-1])), 5.7, 0.05)
    i100 = min(range(len(f)), key=lambda i: abs(f[i].real - 100)); chk("p_open at 100 Hz dB", 20 * math.log10(abs(d["v(p_out)"][i100])), 92.5, 0.01)
    d = run_ltspice(HERE / "Part4_Coil_Electromechanical.asc"); f = d["frequency"]
    print("Part 4"); fr, a = feat(f, d["v(u_c)"], 2, 20); chk("rigid-body mode Hz", fr, 4.90); chk("u_c peak (sign check)", a, 0.652)
    fr, a = feat(f, d["v(u_c)"], 80, 300, "min"); chk("coil stops Hz", fr, 158.5)
    fr, a = feat(f, d["v(u_c)"], 400, 2000); chk("coil-on-spring Hz", fr, 732.8); chk("u_c there", a, 0.537)
    ze = [abs(1 / i) for i in d["i(vs1)"]]; j = max((i for i, x in enumerate(f) if 2 <= x.real <= 20), key=lambda i: ze[i]); chk("Z_E peak ohm", ze[j], 22.6)
    print("\nALL OK" if ok else "\nSOME CHECKS FAILED")
    return ok


if __name__ == "__main__":
    part1(); part3("st", "Stiff"); part3("so", "Soft"); part2("p"); part2("U"); part2("rad"); part4()
    print("wrote", len(list(HERE.glob("*.asc"))), ".asc and", len(list(HERE.glob("*.plt"))), ".plt files in", HERE)
    if "--verify" in sys.argv:
        sys.exit(0 if verify() else 1)
