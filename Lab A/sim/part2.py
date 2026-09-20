#!/usr/bin/env python3
"""Lab A Part 2 -- car silencer: build the KiCad sheets, export, run ngspice,
plot, and print the numbers that go into results/part2.md.

Run from anywhere:  python3 part2.py
"""
import math
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_p24 import (RHO, C0, export_netlist, run_ac, db, deg, save_fig,
                         peaks, score)
import part2_layout as L2

VEC = ["i(vs1)", "i(vs3)", "i(vs5)", "i(vs7)", "v(/p2)", "v(/p4)", "v(/p6)"]

# ---------------------------------------------------------------- build + run
runs = {}
for v, (name, title) in L2.VARIANTS.items():
    folder, el = L2.build(v, name, title)
    cir = export_netlist(folder, name)
    vec = VEC + (["v(/p_out)"] if v == "rad" else [])
    runs[v] = run_ac(cir, vec)
    runs[v]["el"] = el
    print(score(folder / f"{name}.kicad_sch").splitlines()[-1])

f = runs["p"]["f"]

# ---------------------------------------------------------------- element table
print("\n## Element values")
print("| element | value | unit | how |")
print("|---|---|---|---|")
for k, (val, unit, note) in runs["rad"]["el"].items():
    print(f"| {k} | {val:.4g} | {unit} | {note} |")
print(f"| M_A7 (no radiation net) | {runs['p']['el']['M_A7'][0]:.4g} | kg/m^4 | full 40 mm |")

# pair estimates
S = L2.S_TUBE
M = {n: RHO * l / S for n, l in L2.L_TUBE.items()}
C = {n: math.pi * r**2 * l / (RHO * C0**2) for n, (r, l) in L2.CHAMBER.items()}
print("\n## Nearest-neighbour LC estimates f = 1/(2 pi sqrt(M C))")
for (m, c) in [(1, 2), (3, 2), (3, 4), (5, 4), (5, 6), (7, 6)]:
    print(f"  M_A{m} with C_A{c}: {1/(2*math.pi*math.sqrt(M[m]*C[c])):.1f} Hz")
# 'chamber between two tubes' resonance: C with the parallel combination of the tubes on both sides
for c, (ma, mb) in {2: (1, 3), 4: (3, 5), 6: (5, 7)}.items():
    mp = M[ma] * M[mb] / (M[ma] + M[mb])
    print(f"  C_A{c} with M_A{ma}||M_A{mb} ({mp:.0f}): {1/(2*math.pi*math.sqrt(mp*C[c])):.1f} Hz")
Mtot = sum(M.values()); Ctot = sum(C.values())
print(f"  all masses in series ({Mtot:.0f}) with all compliances ({Ctot:.3e}): {1/(2*math.pi*math.sqrt(Mtot*Ctot)):.1f} Hz")

# ---------------------------------------------------------------- a) pressure source
Up = runs["p"]["i(vs7)"]
fig, ax = plt.subplots(2, 1, figsize=(8, 6), sharex=True)
ax[0].semilogx(f, db(Up), lw=1.6, label=r"$|U_{out}/p_{in}|$")
ax[0].set_ylabel(r"$|U_{out}/p_{in}|$  [dB re 1 m$^3$/(s·Pa)]")
ax[0].set_title("Part 2a — silencer driven by a pressure source (1 Pa)")
ax[0].grid(True, which="both", alpha=.3); ax[0].legend()
ax[1].semilogx(f, deg(Up), lw=1.2, color="C1")
ax[1].set_ylabel("phase [°]"); ax[1].set_xlabel("frequency [Hz]")
ax[1].grid(True, which="both", alpha=.3); ax[1].set_xlim(10, 1000)
save_fig(fig, "part2a_pressure_source_Uout")
print("\n## a) pressure source: |U_out/p_in|")
print(f"  at 10 Hz : {db(Up)[0]:.1f} dB  (1/sum R_A = {20*math.log10(1/(4*L2.R_TUBE)):.1f} dB)")
for fr, m in peaks(f, Up, "max", 2):
    print(f"  peak  {fr:7.1f} Hz  {20*np.log10(m):7.1f} dB")
for fr, m in peaks(f, Up, "min", 2):
    print(f"  dip   {fr:7.1f} Hz  {20*np.log10(m):7.1f} dB")
print(f"  at 1 kHz: {db(Up)[-1]:.1f} dB")

# ---------------------------------------------------------------- b) U source
Uu = runs["u"]["i(vs7)"]
fig, ax = plt.subplots(2, 1, figsize=(8, 6), sharex=True)
ax[0].semilogx(f, db(Uu), lw=1.6, label=r"$|U_{out}/U_{in}|$")
ax[0].set_ylabel(r"$|U_{out}/U_{in}|$  [dB]")
ax[0].set_title("Part 2b — silencer driven by a volume-velocity source (1 m³/s)")
ax[0].grid(True, which="both", alpha=.3); ax[0].legend()
ax[1].semilogx(f, deg(Uu), lw=1.2, color="C1")
ax[1].set_ylabel("phase [°]"); ax[1].set_xlabel("frequency [Hz]")
ax[1].grid(True, which="both", alpha=.3); ax[1].set_xlim(10, 1000)
save_fig(fig, "part2b_volume_velocity_source_Uout")
print("\n## b) volume-velocity source: |U_out/U_in|")
print(f"  at 10 Hz : {db(Uu)[0]:.2f} dB")
for fr, m in peaks(f, Uu, "max", 2):
    print(f"  peak  {fr:7.1f} Hz  {20*np.log10(m):7.1f} dB")
for fr, m in peaks(f, Uu, "min", 2):
    print(f"  dip   {fr:7.1f} Hz  {20*np.log10(m):7.1f} dB")
print(f"  at 1 kHz: {db(Uu)[-1]:.1f} dB")
print("  transmission loss TL = -20log|U_out/U_in|:")
for fr in [20, 50, 100, 150, 200, 300, 500, 700, 1000]:
    i = np.argmin(np.abs(f - fr))
    print(f"    {f[i]:6.0f} Hz  TL = {-db(Uu)[i]:6.1f} dB")

# a/b side by side, both normalised to their own LF value is misleading -> raw overlay of shapes
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.semilogx(f, db(Up), lw=1.5, label=r"pressure source: $|U_{out}/p_{in}|$ [dB re 1 m$^3$/(s·Pa)]")
ax.semilogx(f, db(Uu), lw=1.5, label=r"volume-velocity source: $|U_{out}/U_{in}|$ [dB]")
ax.set_xlabel("frequency [Hz]"); ax.set_ylabel("[dB]"); ax.set_xlim(10, 1000)
ax.set_title("Part 2a vs 2b — same network, different source")
ax.grid(True, which="both", alpha=.3); ax.legend(fontsize=8)
save_fig(fig, "part2ab_source_comparison")

# input impedance seen by the pressure source, for the discussion
Zin = 1 / runs["p"]["i(vs1)"]
fig, ax = plt.subplots(figsize=(8, 4.5))
ax.loglog(f, np.abs(Zin), lw=1.5)
ax.set_xlabel("frequency [Hz]"); ax.set_ylabel(r"$|Z_{A,in}| = |p_{in}/U_{in}|$  [Pa·s/m³]")
ax.set_title("Input impedance of the silencer (open outlet)"); ax.set_xlim(10, 1000)
ax.grid(True, which="both", alpha=.3)
save_fig(fig, "part2_input_impedance")
print("\n## input impedance |Z_in| (open outlet)")
print(f"  at 10 Hz: {abs(Zin[0]):.3e}, at 1 kHz: {abs(Zin[-1]):.3e}")
for fr, m in peaks(f, Zin, "min", 2):
    print(f"  Z_in minimum (series resonance) {fr:7.1f} Hz  {m:.3e}")
for fr, m in peaks(f, Zin, "max", 2):
    print(f"  Z_in maximum (anti-resonance)   {fr:7.1f} Hz  {m:.3e}")

# ---------------------------------------------------------------- c) pipe volume velocities
fig, ax = plt.subplots(figsize=(8, 5))
for n in (1, 3, 5, 7):
    ax.semilogx(f, db(runs["u"][f"i(vs{n})"]), lw=1.5, label=f"pipe {n}: $|U_{n}/U_{{in}}|$")
ax.set_xlabel("frequency [Hz]"); ax.set_ylabel("[dB re $U_{in}$]"); ax.set_xlim(10, 1000)
ax.set_title("Part 2c — volume velocity in each narrow pipe, volume-velocity source")
ax.grid(True, which="both", alpha=.3); ax.legend()
save_fig(fig, "part2c_pipe_volume_velocities")
print("\n## c) pipe volume velocities (U source)")
for n in (3, 5, 7):
    u = runs["u"][f"i(vs{n})"]
    print(f"  pipe {n}: at 1 kHz {db(u)[-1]:.1f} dB; peaks:",
          ", ".join(f"{fr:.0f} Hz/{20*np.log10(m):.1f} dB" for fr, m in peaks(f, u, 'max', 2)))

# ---------------------------------------------------------------- d) near-field pressure
r = runs["rad"]
pout = r["v(/p_out)"]; Uout = r["i(vs7)"]
w = 2 * np.pi * f
fig, ax = plt.subplots(figsize=(8, 5))
ax.semilogx(f, db(pout), lw=1.6, label=r"$|p_{open}|$ from the radiation network")
ax.semilogx(f, db(1j * w * L2.M_A1 * Uout), "--", lw=1.2, label=r"$\omega M_{A1}|U_{out}|$ (mass only)")
ax.set_xlabel("frequency [Hz]"); ax.set_ylabel(r"$|p_{open}|$  [dB re 1 Pa, for $U_{in}$ = 1 m³/s]")
ax.set_title("Part 2d — sound pressure at the opening of pipe 7"); ax.set_xlim(10, 1000)
ax.grid(True, which="both", alpha=.3); ax.legend()
save_fig(fig, "part2d_near_field_pressure")
Zrad = pout / Uout
print("\n## d) near-field pressure at the opening (U_in = 1 m^3/s)")
print(f"  |p_open| at 10 Hz {db(pout)[0]:.1f} dB, 100 Hz {db(pout)[np.argmin(abs(f-100))]:.1f} dB, 1 kHz {db(pout)[-1]:.1f} dB")
print(f"  |Z_rad| at 1 kHz {abs(Zrad[-1]):.3e} vs wM_A1 {w[-1]*L2.M_A1:.3e}; Re(Z_rad) {Zrad[-1].real:.3e}, Im {Zrad[-1].imag:.3e}")
print(f"  ka at 1 kHz = {w[-1]*L2.A_TUBE/C0:.4f}")
print("  effect of the radiation load on U_out vs open end (dB):",
      ", ".join(f"{fr} Hz: {db(Uout)[np.argmin(abs(f-fr))]-db(Uu)[np.argmin(abs(f-fr))]:+.2f}" for fr in (50, 100, 300, 1000)))
for fr, m in peaks(f, Uout, "max", 2):
    print(f"  U_out (radiation) peak {fr:7.1f} Hz {20*np.log10(m):7.1f} dB")

# ---------------------------------------------------------------- e) pressure at 10 m
R = 10.0
p10 = 1j * w * RHO * Uout / (4 * np.pi * R)       # free-space point source, |e^{-jkr}| = 1
fig, ax = plt.subplots(figsize=(8, 5))
ax.semilogx(f, 20 * np.log10(np.abs(p10) / 20e-6), lw=1.6, label=r"$|p(10\,\mathrm{m})|$, $U_{in}$ = 1 m³/s")
ax.semilogx(f, 20 * np.log10(np.abs(1j * w * RHO * 1.0 / (4 * np.pi * R)) / 20e-6), "--", lw=1.2,
            label=r"unsilenced reference: $U_{out} = U_{in}$")
ax.axvspan(344, 1000, color="grey", alpha=.15, label="lumped model doubtful ($l > \\lambda/10$ for pipe 5)")
ax.set_xlabel("frequency [Hz]"); ax.set_ylabel("SPL [dB re 20 µPa]"); ax.set_xlim(10, 1000)
ax.set_title("Part 2e — far-field pressure 10 m from the exit pipe (free space)")
ax.grid(True, which="both", alpha=.3); ax.legend(fontsize=8)
save_fig(fig, "part2e_pressure_10m")
print("\n## e) pressure at 10 m (U_in = 1 m^3/s)")
for fr in (20, 50, 100, 200, 500, 1000):
    i = np.argmin(abs(f - fr))
    print(f"  {f[i]:6.0f} Hz  SPL {20*np.log10(abs(p10[i])/20e-6):6.1f} dB   (unsilenced {20*np.log10(abs(w[i]*RHO/(4*np.pi*R))/20e-6):6.1f} dB)")
print("  lumped-element limit l < lambda/10:")
for n, l in sorted(L2.L_TUBE.items()):
    print(f"    pipe {n} l={l*1e3:.0f} mm -> f < {C0/(10*l):.0f} Hz")
for n, (rr, l) in sorted(L2.CHAMBER.items()):
    print(f"    chamber {n} l={l*1e3:.0f} mm -> f < {C0/(10*l):.0f} Hz; first length mode c/(2l) = {C0/(2*l):.0f} Hz; radius {rr*1e3:.0f} mm -> ka=1 at {C0/(2*np.pi*rr):.0f} Hz")
