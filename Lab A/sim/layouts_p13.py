#!/usr/bin/env python3
"""Schematic layouts for Lab A Parts 1 and 3 (dual-diaphragm loudspeaker).

Mechanical MOBILITY analogy: velocity u = node voltage, force f = current.
  mass M      -> capacitor  C = M        (to ground)
  compliance  -> inductor   L = C_m
  damper R_m  -> resistor   R = 1/R_m
Acoustic IMPEDANCE analogy (Part 3 radiation networks): p = voltage, U = current.
  M_A -> L, R_A -> R, C_A -> C (grounded).
Coupling via two VCCS per diaphragm (Lecture 4A slide 8, mobility form):
  G_a injects U = S*u into the acoustic node, G_m draws f = S*p from the velocity node.
"""
from __future__ import annotations

import math

from common_p13 import G, RHO, C0, ctrl, isrc, fmt, topbot

# ---- Table 1 of the lab ---------------------------------------------------
MMD, MMVC = 5e-3, 6e-3                 # kg
CMSP, CMSR = 1.3e-3, 2.7e-3            # m/N
RMSP, RMSR = 0.5, 0.22                 # Ns/m
VARIANTS = {
    "Stiff": dict(CMD=1e-10, RMD=5000.0),
    "Soft":  dict(CMD=3e-6,  RMD=5.0),
}
S_I, S_O = 60e-4, 210e-4               # m^2 (Part 3)


def baffled_piston(a, sides=2):
    """Lumped radiation network of a piston in an infinite baffle, one side,
    scaled to `sides` identical sides in series (2 -> both faces)."""
    S = math.pi * a * a
    MA1 = 8 * RHO / (3 * math.pi ** 2 * a)
    RA1 = 0.441 * RHO * C0 / S
    RA2 = RHO * C0 / S
    CA1 = 5.94 * a ** 3 / (RHO * C0 ** 2)
    return dict(a=a, S=S, MA1=sides * MA1, RA1=sides * RA1, RA2=sides * RA2,
                CA1=CA1 / sides, MA1_1=MA1, RA1_1=RA1, RA2_1=RA2, CA1_1=CA1)


def draw(sh, variant: str, radiation: bool):
    """Draw the sheet; return (sim_fields, values) for finish_project()."""
    v = VARIANTS[variant]
    TOP, BOT = G(42), G(64)          # u rails / mechanical ground rail (notes block sits above)
    YC = G(52)                       # centre line of vertical elements
    fields = {}
    vals = {"M_mvc": MMVC, "M_md": MMD, "C_msp": CMSP, "C_msr": CMSR,
            "R_msp": RMSP, "R_msr": RMSR, "C_md": v["CMD"], "R_md": v["RMD"]}

    # ---- force source: 1 N -> 1 A injected INTO u_vc ------------------------
    # rot=180 puts pin 2 (-) on top: current leaves the '-' terminal into the node.
    i1 = sh.place("Simulation_SPICE:IDC", "I1", at=(G(8), YC), rot=180, value="1")
    fields["I1"] = isrc(1)
    i1_top, i1_bot = topbot(i1)
    sh.wire(i1_top, (i1_top.x, TOP))
    sh.wire(i1_bot, (i1_bot.x, BOT))

    def shunt(ref, lib, x, value):
        p = sh.place(lib, ref, at=(x, YC), rot=0, value=value)
        t, b = topbot(p)
        sh.wire(t, (t.x, TOP))
        sh.wire(b, (b.x, BOT))
        return p

    # ---- u_vc node: M_mvc || C_msp || 1/R_msp ---------------------------------
    shunt("C1", "Device:C", G(18), fmt(MMVC))
    shunt("L1", "Device:L", G(28), fmt(CMSP))
    shunt("R1", "Device:R", G(38), fmt(1 / RMSP))
    X_VC_END = G(54)
    sh.wire((i1_top.x, TOP), (X_VC_END, TOP))
    sh.label((G(13), TOP), "u_vc")

    # ---- link between the two masses: C_md || 1/R_md ---------------------------
    # drawn as a two-branch loop hanging below the (interrupted) u rail
    LNK1, LNK2 = TOP + G(6), TOP + G(12)
    l2 = sh.place("Device:L", "L2", at=(G(62), LNK1), rot=90, value=fmt(v["CMD"]))
    r2 = sh.place("Device:R", "R2", at=(G(62), LNK2), rot=90, value=fmt(1 / v["RMD"]))
    l2a, l2b = (l2.pin(1), l2.pin(2)) if l2.pin(1).x < l2.pin(2).x else (l2.pin(2), l2.pin(1))
    r2a, r2b = (r2.pin(1), r2.pin(2)) if r2.pin(1).x < r2.pin(2).x else (r2.pin(2), r2.pin(1))
    sh.wire((X_VC_END, TOP), (X_VC_END, LNK2))
    sh.wire((X_VC_END, LNK1), l2a)
    sh.wire((X_VC_END, LNK2), r2a)
    X_D_START = G(70)
    sh.wire(l2b, (X_D_START, LNK1))
    sh.wire(r2b, (X_D_START, LNK2))
    sh.wire((X_D_START, LNK2), (X_D_START, TOP))

    # ---- u_d node: M_md || C_msr || 1/R_msr ----------------------------------
    shunt("C2", "Device:C", G(76), fmt(MMD))
    shunt("L3", "Device:L", G(86), fmt(CMSR))
    shunt("R3", "Device:R", G(96), fmt(1 / RMSR))
    X_D_END = G(108) if radiation else G(96)   # end ON the last pin, no dangling stub
    sh.wire((X_D_START, TOP), (X_D_END, TOP))
    sh.label((G(72), TOP), "u_d")

    # ---- mechanical ground rail ------------------------------------------------
    X_BOT_END = G(108) if radiation else G(96)
    sh.wire((i1_bot.x, BOT), (X_BOT_END, BOT))
    sh.gnd((G(58), BOT), drop=G(4))
    sh.wire((G(66), BOT), (G(66), BOT + G(4)))
    sh.power("power:PWR_FLAG", (G(66), BOT + G(4)))

    notes = [
        (f"Lab A Part {'3' if radiation else '1'} - Dual-diaphragm loudspeaker, {variant.upper()} link "
         f"(mobility analogy: u = V, f = I)", 1.6),
        (f"I1 = F = 1 N (1 A into u_vc).  C1 = M_mvc = {fmt(MMVC)} kg   C2 = M_md = {fmt(MMD)} kg", 1.3),
        (f"L1 = C_msp = {fmt(CMSP)} m/N   R1 = 1/R_msp = {fmt(1/RMSP)} (R_msp = {RMSP} Ns/m)", 1.3),
        (f"L3 = C_msr = {fmt(CMSR)} m/N   R3 = 1/R_msr = {fmt(1/RMSR)} (R_msr = {RMSR} Ns/m)", 1.3),
        (f"L2 = C_md = {fmt(v['CMD'])} m/N   R2 = 1/R_md = {fmt(1/v['RMD'])} (R_md = {v['RMD']} Ns/m)", 1.3),
        ("Z_M seen by the force = 1/V(u_vc)   (1 A source)", 1.3),
    ]

    if radiation:
        vals.update(_radiation(sh, fields, TOP, BOT, YC))
        notes += [
            ("Part 3: G_m draws f = S*p from each velocity node, G_a injects U = S*u into", 1.3),
            ("the acoustic node; L/R/C below = both-sides baffled-piston radiation impedance.", 1.3),
            ("p_front (one side) = V(p_x)/2.   S_i = 60 cm2 (a = 43.7 mm), S_o = 210 cm2 (a = 81.8 mm)", 1.3),
        ]

    y = G(6)
    for txt, size in notes:
        sh.note((G(6), y), txt, size=size)
        y += G(3)
    return fields, vals


def _radiation(sh, fields, TOP, BOT, YC):
    """Two coupling pairs + two acoustic sub-networks under the mechanical band."""
    vals = {}
    YA = G(84)            # G_a centre
    PR = G(92)            # p rails
    Y_R2 = G(98)          # series R_A2
    MID = G(104)          # node between R_A2 and R_A1||C_A1
    Y_RC = G(110)         # R_A1 || C_A1 centre
    AG = G(116)           # acoustic ground rail

    for tag, S, x0, xg in (("i", S_I, G(12), G(48)), ("o", S_O, G(72), G(108))):
        a = math.sqrt(S / math.pi)
        rad = baffled_piston(a, sides=2)
        vals[f"rad_{tag}"] = rad
        u_lbl, p_lbl = ("u_vc", "p_i") if tag == "i" else ("u_d", "p_o")

        # -- G_m: force f = S*p drawn from the velocity node (in the mech band)
        gm = sh.place("Simulation_SPICE:GSOURCE", f"G{'1' if tag=='i' else '3'}",
                      at=(xg, YC), rot=0, value="GSOURCE")
        fields[gm.ref] = ctrl("G", S)
        gp = {p.name: p for p in gm.pins}
        sh.wire(gp["N+"], (gp["N+"].x, TOP))
        sh.wire(gp["N-"], (gp["N-"].x, BOT))
        sh.wire(gp["C-"], (gp["C-"].x, BOT))
        sh.wire(gp["C+"], (gp["C+"].x, TOP + G(4)))
        sh.label((gp["C+"].x, TOP + G(4)), p_lbl)

        # -- G_a: volume velocity U = S*u injected into the p node
        ga = sh.place("Simulation_SPICE:GSOURCE", f"G{'2' if tag=='i' else '4'}",
                      at=(x0, YA), rot=0, value="GSOURCE")
        fields[ga.ref] = ctrl("G", S)
        ap = {p.name: p for p in ga.pins}
        sh.wire(ap["N+"], (ap["N+"].x, YA - G(8)))
        sh.power("power:GND", (ap["N+"].x, YA - G(8)), rot=180)
        sh.wire(ap["N-"], (ap["N-"].x, PR))
        sh.gnd(ap["C-"], drop=G(4))
        sh.wire(ap["C+"], (ap["C+"].x, YA - G(5)), (ap["C+"].x - G(4), YA - G(5)))
        sh.label((ap["C+"].x - G(4), YA - G(5)), u_lbl)

        # -- acoustic network: L(2M_A1) || [R(2R_A2) + (R(2R_A1) || C(C_A1/2))]
        xl, xr, xc = x0 + G(8), x0 + G(18), x0 + G(28)
        n = "5" if tag == "i" else "6"
        L = sh.place("Device:L", f"L{'4' if tag=='i' else '5'}", at=(xl, MID), rot=0, value=fmt(rad["MA1"]))
        lt, lb = topbot(L)
        sh.wire(lt, (lt.x, PR)); sh.wire(lb, (lb.x, AG))
        Rs = sh.place("Device:R", f"R{'4' if tag=='i' else '6'}", at=(xr, Y_R2), rot=0, value=fmt(rad["RA2"]))
        rt, rb = topbot(Rs)
        sh.wire(rt, (rt.x, PR)); sh.wire(rb, (rb.x, MID))
        Rp = sh.place("Device:R", f"R{'5' if tag=='i' else '7'}", at=(xr, Y_RC), rot=0, value=fmt(rad["RA1"]))
        pt, pb = topbot(Rp)
        sh.wire(pt, (pt.x, MID)); sh.wire(pb, (pb.x, AG))
        Cp = sh.place("Device:C", f"C{'3' if tag=='i' else '4'}", at=(xc, Y_RC), rot=0, value=fmt(rad["CA1"]))
        ct, cb = topbot(Cp)
        sh.wire(ct, (ct.x, MID)); sh.wire(cb, (cb.x, AG))
        sh.wire((xr, MID), (xc, MID))
        sh.wire((ap["N-"].x, PR), (xr, PR))
        sh.label((x0 + G(3), PR), p_lbl)
        sh.wire((xl, AG), (xc, AG))
        sh.gnd((xl + G(4), AG), drop=G(4))
        sh.note((G(12), AG + G(8) + (G(3) if tag == "o" else 0)),
                f"{'Inner' if tag=='i' else 'Outer'} diaphragm, both sides: 2M_A1={fmt(rad['MA1'])}  "
                f"2R_A2={fmt(rad['RA2'])}  2R_A1={fmt(rad['RA1'])}  C_A1/2={fmt(rad['CA1'])}", size=1.2)
    return vals
