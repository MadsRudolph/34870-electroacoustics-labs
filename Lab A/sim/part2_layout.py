#!/usr/bin/env python3
"""Lab A Part 2 -- car silencer as an acoustic ladder network (impedance analogy).

p = node voltage [Pa], U = branch current [m^3/s].
Narrow tubes 1,3,5,7 : series R_A (25e3, viscous loss) + L = M_A = rho*l/S.
Chambers 2,4,6       : shunt C = C_A = V/(rho c^2) to ground (compliances are ALWAYS grounded).
Each tube carries a 0 V sense source Vs_n so the pipe volume velocity is I(Vs_n).

Variants:
  'p'   pressure source (1 Pa), ideal open outlet            -> Part2a
  'u'   volume-velocity source (1 m^3/s), ideal open outlet   -> Part2b
  'rad' volume-velocity source + radiation network at outlet  -> Part2d
"""
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_p24 import (G, RHO, C0, KICAD_DIR, ctrl, vsrc, isrc, fmt,
                         write_project, write_ac_workbook)
from schdraw import Sheet
from simfields import set_sim

AC_CMD = ".ac dec 2000 10 1000"   # Q > 100: 200 points per decade clips the peaks
R_TUBE = 25e3           # Pa s/m^3 per narrow tube (given)
A_TUBE = 2e-3           # m, radius of tubes 1,3,5,7
S_TUBE = math.pi * A_TUBE ** 2
L_TUBE = {1: 25e-3, 3: 80e-3, 5: 100e-3, 7: 40e-3}          # effective lengths
CHAMBER = {2: (10e-3, 50e-3), 4: (20e-3, 80e-3), 6: (15e-3, 60e-3)}  # (radius, length)

# Radiation impedance of the open end of pipe 7: "piston in a long tube"
# (unflanged), Lecture 3 s8b.  Z_rad = jwM_A1 || [R_A2 + (R_A1 || C_A1)]
M_A1 = 0.6133 * RHO / (math.pi * A_TUBE)
C_A1 = 0.55 * math.pi ** 2 * A_TUBE ** 3 / (RHO * C0 ** 2)
R_A1 = 0.5045 * RHO * C0 / (math.pi * A_TUBE ** 2)
R_A2 = RHO * C0 / (math.pi * A_TUBE ** 2)
END_CORR = 0.6133 * A_TUBE   # the end-correction mass already inside the effective length


def elements(with_radiation=False):
    """Physical -> SPICE values. Returns dict of name -> (value, unit, note)."""
    el = {}
    for n, l in L_TUBE.items():
        leff = l - END_CORR if (with_radiation and n == 7) else l
        el[f"M_A{n}"] = (RHO * leff / S_TUBE, "kg/m^4",
                         f"rho*l/S, l={leff*1e3:.2f} mm, S={S_TUBE:.4e} m^2")
        el[f"R_A{n}"] = (R_TUBE, "Pa s/m^3", "given viscous loss")
    for n, (r, l) in CHAMBER.items():
        V = math.pi * r ** 2 * l
        el[f"C_A{n}"] = (V / (RHO * C0 ** 2), "m^5/N",
                         f"V/(rho c^2), V={V*1e6:.2f} cm^3")
    if with_radiation:
        el["M_A1rad"] = (M_A1, "kg/m^4", "0.6133 rho/(pi a)")
        el["C_A1rad"] = (C_A1, "m^5/N", "0.55 pi^2 a^3/(rho c^2)")
        el["R_A1rad"] = (R_A1, "Pa s/m^3", "0.5045 rho c/(pi a^2)")
        el["R_A2rad"] = (R_A2, "Pa s/m^3", "rho c/(pi a^2)")
    return el


def lr(part):
    a, b = part.pin(1), part.pin(2)
    return (a, b) if a.x < b.x else (b, a)


def topbot(part):
    a, b = part.pin(1), part.pin(2)
    return (a, b) if a.y < b.y else (b, a)


def build(variant: str, name: str, title: str):
    folder = KICAD_DIR / name
    folder.mkdir(parents=True, exist_ok=True)
    rad = variant == "rad"
    el = elements(with_radiation=rad)

    sh = Sheet(paper="A4", title=title, project=name)
    RAIL = G(30)      # p-rail (top)
    BOT = G(56)       # reference pressure (ground) rail
    sims = {}

    # ---- source block (left) ----------------------------------------------
    if variant == "p":
        src = sh.place("Simulation_SPICE:VDC", "V1", at=(G(12), RAIL + G(4)), value="1")
        sims["V1"] = vsrc("dc=0 ac=1")
        src_note = "V1 = pressure source, 1 Pa AC"
    else:
        src = sh.place("Simulation_SPICE:IDC", "I1", at=(G(12), RAIL + G(4)), value="1")
        sims["I1"] = isrc("dc=0 ac=1")
        src_note = "I1 = volume-velocity source, 1 m^3/s AC"
    s_top, s_bot = topbot(src)
    sh.wire(s_top, (s_top.x, RAIL))
    sh.wire(s_bot, (s_bot.x, BOT))
    if variant != "p":
        rl = sh.place("Device:R", "R0", at=(G(20), RAIL + G(13)), value="1T")   # was 100Meg: that loaded the source at the ladder anti-resonances (|Z_in| up to 1.5 G) and cut the 2b peaks by 13 dB
        rt, rb = topbot(rl)
        sh.wire(rt, (rt.x, RAIL))
        sh.wire(rb, (rb.x, BOT))
    sh.label((G(16), RAIL), "p_in", kind="local")

    # ---- ladder: four tube sections, three chambers ------------------------
    x = G(24)
    order = [1, 2, 3, 4, 5, 6, 7]
    last_x = s_top.x
    shunt_pins = []
    for n in order:
        if n % 2 == 1:   # narrow tube: Vs -> R -> L in series on the rail
            vs = sh.place("Simulation_SPICE:VDC", f"Vs{n}", at=(x + G(4), RAIL), rot=90, value="0")
            sims[f"Vs{n}"] = vsrc("dc=0")
            r = sh.place("Device:R", f"R{n}", at=(x + G(14), RAIL), rot=90, value=fmt(el[f"R_A{n}"][0]))
            l = sh.place("Device:L", f"L{n}", at=(x + G(22), RAIL), rot=90, value=fmt(el[f"M_A{n}"][0]))
            vl, vr = lr(vs)
            # the sense source must have + upstream so I(Vs) is the flow direction
            if vs.pin(1) is not vl:
                raise SystemExit(f"Vs{n}: pin 1 is not on the left, fix rotation")
            rl_, rr_ = lr(r)
            ll_, lr_ = lr(l)
            sh.wire((last_x, RAIL), vl)
            sh.wire(vr, rl_)
            sh.wire(rr_, ll_)
            last_x = lr_.x
            if n == 7 and not rad:
                # ideal open end: p_out = 0 -> straight to the reference rail
                sh.wire(lr_, (lr_.x + G(4), RAIL), (lr_.x + G(4), BOT))
                sh.label((lr_.x + G(2), RAIL), "p_out", kind="local")
                end_x = lr_.x + G(4)
        else:            # chamber: shunt compliance from the rail to ground
            c = sh.place("Device:C", f"C{n}", at=(x + G(4), RAIL + G(3)), value=fmt(el[f"C_A{n}"][0]))
            ct, cb = topbot(c)
            sh.wire((last_x, RAIL), ct)
            sh.wire(cb, (cb.x, BOT))
            sh.label((ct.x, RAIL), f"p{n}", kind="local")
            last_x = ct.x
        x += G(28) if n % 2 == 1 else G(8)

    if rad:
        # radiation network at the outlet of pipe 7
        px = last_x + G(4)
        sh.wire((last_x, RAIL), (px, RAIL))
        sh.label((px, RAIL), "p_out", kind="local")
        lm = sh.place("Device:L", "L9", at=(px + G(4), RAIL + G(3)), value=fmt(M_A1))
        lt, lb = topbot(lm)
        sh.wire((px, RAIL), lt)
        sh.wire(lb, (lb.x, BOT))
        r2 = sh.place("Device:R", "R9", at=(px + G(14), RAIL + G(3)), value=fmt(R_A2))
        r2t, r2b = topbot(r2)
        sh.wire(lt, (r2t.x, RAIL), r2t)
        MID = r2b.y + G(2)
        sh.wire(r2b, (r2b.x, MID))
        r1 = sh.place("Device:R", "R8", at=(px + G(14), MID + G(3)), value=fmt(R_A1))
        r1t, r1b = topbot(r1)
        sh.wire((r2b.x, MID), r1t)
        sh.wire(r1b, (r1b.x, BOT))
        c1 = sh.place("Device:C", "C9", at=(px + G(22), MID + G(3)), value=fmt(C_A1))
        c1t, c1b = topbot(c1)
        sh.wire((r2b.x, MID), (c1t.x, MID), c1t)
        sh.wire(c1b, (c1b.x, BOT))
        end_x = c1b.x

    # ---- reference rail, one ground + PWR_FLAG ------------------------------
    sh.wire((s_bot.x, BOT), (end_x, BOT))
    sh.gnd((G(12), BOT), drop=G(4))
    sh.wire((G(28), BOT), (G(28), BOT + G(4)))
    sh.power("power:PWR_FLAG", (G(28), BOT + G(4)))

    # ---- notes ---------------------------------------------------------------
    y = G(8)
    sh.note((G(10), y), title, size=1.8); y += G(4)
    sh.note((G(10), y), src_note + "   |   p = V [Pa], U = I [m^3/s]   |   I(Vs_n) = volume velocity in pipe n", size=1.3); y += G(3)
    sh.note((G(10), y), "Tubes 1,3,5,7: R = R_A = 25e3 Pa s/m^3 (given), L = M_A = rho*l/S  (a = 2 mm)", size=1.3); y += G(3)
    sh.note((G(10), y), "Chambers 2,4,6: C = C_A = V/(rho c^2), grounded (reference pressure)", size=1.3); y += G(3)
    if rad:
        sh.note((G(10), y), "Outlet: Z_rad = jwL9 || [R9 + (R8 || C9)] = jwM_A1 || [R_A2 + (R_A1 || C_A1)] (unflanged end); pipe 7 shortened by 0.6133a; R0 = DC leak", size=1.3); y += G(3)
    sh.note((G(150), G(10)), "SPICE directive (read automatically):", size=1.3)
    sh.note((G(150), G(14)), AC_CMD, size=1.8)

    problems = sh.check()
    print(f"[{name}] check(): {problems}")
    assert problems == [], problems
    for net, members in sh.netlist().items():
        print(f"   {net}: {sorted(members)}")
    out = folder / f"{name}.kicad_sch"
    sh.emit(str(out))
    set_sim(out, sims)
    write_project(folder, name, sh.uuid)
    sig = ["I(Vs1)", "I(Vs3)", "I(Vs5)", "I(Vs7)"]
    if rad:
        sig = ["V(/p_out)"] + sig
    write_ac_workbook(folder, name, AC_CMD, sig, phase_for=["I(Vs7)"])
    return folder, el


VARIANTS = {
    "p": ("Part2a_Silencer_PressureSource", "Lab A Part 2a - Silencer driven by a pressure source"),
    "u": ("Part2b_Silencer_VolumeVelocitySource", "Lab A Part 2b/c - Silencer driven by a volume-velocity source"),
    "rad": ("Part2d_Silencer_Radiation", "Lab A Part 2d/e - Silencer with radiation impedance at the outlet"),
}

if __name__ == "__main__":
    for v, (nm, t) in VARIANTS.items():
        build(v, nm, t)
