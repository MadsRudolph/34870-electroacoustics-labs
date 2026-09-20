#!/usr/bin/env python3
"""Lab A Part 4 -- coil in a magnetic field driving a two-mass suspension
(coupled electrical + mechanical system), MOBILITY analogy on the mechanical side.

Electrical loop  : V1 (1 V) -> Vs (0 V sense) -> Rc -> Le -> E_bemf -> GND
                   coil current i = I(Vs), back-EMF v_b = Bl * u_c  (ESOURCE, gain Bl)
Coil force       : f = Bl * i  = (Bl/Rc) * V(Rc)   -> GSOURCE sensing across Rc,
                   injecting the force-current into node u_c   (1 A = 1 N)
Mechanical (mobility, u = V, f = I):
   u_c  : C = M_mc to ground
   u_c--u_1 : L = C_ms || R = 1/R_ms
   u_1  : C = M_m1 || L = C_ms2 || R = 1/R_ms2 to ground
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_p24 import (G, KICAD_DIR, ctrl, vsrc, fmt, write_project,
                         write_ac_workbook)
from schdraw import Sheet
from simfields import set_sim

AC_CMD = ".ac dec 200 1 10k"

B, l = 1.0, 1.5
BL = B * l                 # 1.5 T m
RC, LE = 0.5, 10e-6
MMC = 5e-3
CMS, RMS = 0.01e-3, 1.0
CMS2, RMS2 = 10e-3, 0.1
MM1 = 100e-3

ELEMENTS = {
    "R1 (Rc)":   (RC, "ohm", "coil resistance (given)"),
    "L1 (Le)":   (LE, "H", "coil inductance (given)"),
    "E1 gain (back-EMF)": (BL, "V/(m/s) = T m", "back-EMF v = Bl u_c"),
    "G1 gain (force)": (BL / RC, "A/V", "f = Bl i = (Bl/Rc) V(Rc), 1 A = 1 N"),
    "C1 (M_mc)": (MMC, "F (= kg)", "coil mass M_mc, capacitor to ground"),
    "L2 (C_ms)": (CMS, "H (= m/N)", "coil-to-mass spring compliance C_ms"),
    "R2 (1/R_ms)": (1 / RMS, "ohm (= m/(N s))", "1/R_ms, damper coil-to-mass"),
    "C2 (M_m1)": (MM1, "F (= kg)", "large mass M_m1"),
    "L3 (C_ms2)": (CMS2, "H (= m/N)", "suspension compliance C_ms2 to ground"),
    "R3 (1/R_ms2)": (1 / RMS2, "ohm", "1/R_ms2, damper to ground"),
}


def lr(part):
    a, b = part.pin(1), part.pin(2)
    return (a, b) if a.x < b.x else (b, a)


def topbot(part):
    a, b = part.pin(1), part.pin(2)
    return (a, b) if a.y < b.y else (b, a)


def build(name="Part4_Coil_Electromechanical", bemf_gain=BL):
    folder = KICAD_DIR / name
    folder.mkdir(parents=True, exist_ok=True)
    title = "Lab A Part 4 - Coil in a magnetic field, coupled electro-mechanical (mobility analogy)"
    sh = Sheet(paper="A4", title=title, project=name)
    RAIL = G(30)
    BOT = G(56)
    sims = {}

    # ---------------- electrical domain (left) ------------------------------
    v1 = sh.place("Simulation_SPICE:VDC", "V1", at=(G(12), RAIL + G(4)), value="1")
    sims["V1"] = vsrc("dc=0 ac=1")
    vt, vb = topbot(v1)
    sh.wire(vt, (vt.x, RAIL)); sh.wire(vb, (vb.x, BOT))
    sh.label((vt.x + G(2), RAIL), "e_in", kind="local")

    vs = sh.place("Simulation_SPICE:VDC", "Vs1", at=(G(24), RAIL), rot=90, value="0")
    sims["Vs1"] = vsrc("dc=0")
    sl, sr = lr(vs)
    assert vs.pin(1) is sl, "Vs1 + must be upstream so I(Vs1) = coil current"
    sh.wire((vt.x, RAIL), sl)

    rc = sh.place("Device:R", "R1", at=(G(36), RAIL), rot=90, value=fmt(RC))
    rl, rr = lr(rc)
    sh.wire(sr, rl)
    sh.label((rl.x - G(2), RAIL), "e_a", kind="local")

    le = sh.place("Device:L", "L1", at=(G(48), RAIL), rot=90, value=fmt(LE))
    ll, lr_ = lr(le)
    sh.wire(rr, ll)
    sh.label((ll.x - G(2), RAIL), "e_b", kind="local")

    # back-EMF: ESOURCE with N+ on the rail, N- to ground, sensing u_c
    eb = sh.place("Simulation_SPICE:ESOURCE", "E1", at=(G(64), RAIL + G(8)), value="ESOURCE")
    sims["E1"] = ctrl("E", bemf_gain)
    ep = {p.name: p for p in eb.pins}
    sh.wire(lr_, (ep["N+"].x, RAIL), ep["N+"])
    sh.wire(ep["N-"], (ep["N-"].x, BOT))
    sh.wire(ep["C+"], (ep["C+"].x - G(4), ep["C+"].y))
    sh.label((ep["C+"].x - G(4), ep["C+"].y), "u_c", kind="local")
    sh.wire(ep["C-"], (ep["C-"].x, BOT))
    sh.label((lr_.x + G(2), RAIL), "e_c", kind="local")

    # ---------------- transduction: force source into u_c --------------------
    # GSOURCE mirrored on x so N- (output) is on top -> current leaves N- INTO the u_c rail
    gf = sh.place("Simulation_SPICE:GSOURCE", "G1", at=(G(88), RAIL + G(8)), value="GSOURCE", mirror="x")
    sims["G1"] = ctrl("G", BL / RC)
    gp = {p.name: p for p in gf.pins}
    top_out = gp["N-"] if gp["N-"].y < gp["N+"].y else gp["N+"]
    bot_out = gp["N+"] if top_out is gp["N-"] else gp["N-"]
    assert top_out is gp["N-"], "G1: N- must be on the rail so the force is injected into u_c"
    sh.wire(top_out, (top_out.x, RAIL))
    sh.wire(bot_out, (bot_out.x, BOT))
    # sense across Rc: C+ = upstream (e_a), C- = downstream (e_b)
    for pin, lab in ((gp["C+"], "e_a"), (gp["C-"], "e_b")):
        sh.wire(pin, (pin.x - G(4), pin.y)); sh.label((pin.x - G(4), pin.y), lab, kind="local")

    # ---------------- mechanical domain (right), mobility analogy -------------
    UC_X0 = top_out.x
    cm = sh.place("Device:C", "C1", at=(G(100), RAIL + G(3)), value=fmt(MMC))
    ct, cb = topbot(cm)
    sh.wire((UC_X0, RAIL), ct)
    sh.wire(cb, (cb.x, BOT))
    sh.label((G(96), RAIL), "u_c", kind="local")

    # series link u_c -> u_1 : L_Cms on the rail, R_Rms below it, joined at both ends
    lk = sh.place("Device:L", "L2", at=(G(114), RAIL), rot=90, value=fmt(CMS))
    kl, kr = lr(lk)
    rk = sh.place("Device:R", "R2", at=(G(114), RAIL + G(8)), rot=90, value=fmt(1 / RMS))
    rkl, rkr = lr(rk)
    sh.wire(ct, kl)
    sh.wire(kl, (kl.x, rkl.y), rkl)
    sh.wire(kr, (kr.x, rkr.y), rkr)

    c1 = sh.place("Device:C", "C2", at=(G(128), RAIL + G(3)), value=fmt(MM1))
    c1t, c1b = topbot(c1)
    sh.wire(kr, c1t)
    sh.wire(c1b, (c1b.x, BOT))
    sh.label((G(124), RAIL), "u_1", kind="local")
    l2 = sh.place("Device:L", "L3", at=(G(138), RAIL + G(3)), value=fmt(CMS2))
    l2t, l2b = topbot(l2)
    sh.wire(c1t, l2t)
    sh.wire(l2b, (l2b.x, BOT))
    r2 = sh.place("Device:R", "R3", at=(G(148), RAIL + G(3)), value=fmt(1 / RMS2))
    r2t, r2b = topbot(r2)
    sh.wire(l2t, r2t)
    sh.wire(r2b, (r2b.x, BOT))

    # ---------------- ground rail ----------------------------------------------
    sh.wire((vb.x, BOT), (r2b.x, BOT))
    sh.gnd((vb.x, BOT), drop=G(4))
    sh.wire((G(30), BOT), (G(30), BOT + G(4)))
    sh.power("power:PWR_FLAG", (G(30), BOT + G(4)))

    # ---------------- notes ------------------------------------------------------
    y = G(8)
    sh.note((G(10), y), title, size=1.8); y += G(4)
    sh.note((G(10), y), "Electrical: V1 = 1 V AC, I(Vs1) = coil current i, R1 = Rc = 0.5, L1 = Le = 10u, E1 = back-EMF = Bl*u_c (Bl = 1.5 T m)", size=1.3); y += G(3)
    sh.note((G(10), y), "Coupling: G1 = (Bl/Rc)*(V(e_a)-V(e_b)) = Bl*i = coil force (1 A = 1 N), injected into node u_c", size=1.3); y += G(3)
    sh.note((G(10), y), "Mechanical (mobility): u = V [m/s], f = I [N]; M -> C [F], C_m -> L [H], R_m -> R = 1/R_m [ohm]", size=1.3); y += G(3)
    sh.note((G(10), y), "C1 = M_mc = 5m, L2 = C_ms = 10u || R2 = 1/R_ms = 1, C2 = M_m1 = 100m, L3 = C_ms2 = 10m, R3 = 1/R_ms2 = 10", size=1.3); y += G(3)
    sh.note((G(10), y), "Z_M seen by the force = Bl*I(Vs1)/V(u_c);  Z_E = V(e_in)/I(Vs1) = 1/I(Vs1)", size=1.3)
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
    write_ac_workbook(folder, name, AC_CMD,
                      ["V(/u_c)", "V(/u_1)", "I(Vs1)", "1/I(Vs1)", "1.5*I(Vs1)/V(/u_c)"],
                      phase_for=["V(/u_c)", "V(/u_1)"])
    return folder


if __name__ == "__main__":
    build()
