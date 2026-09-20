#!/usr/bin/env python3
"""Lab A Part 4 -- coil in a magnetic field: build, export, run, plot, numbers.

Run from anywhere:  python3 part4.py
"""
import math
import re
import shutil
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_p24 import (export_netlist, run_ac, db, deg, save_fig, peaks, score, LAB)
import part4_layout as L4

VEC = ["v(/u_c)", "v(/u_1)", "i(vs1)", "v(/e_c)"]
folder = L4.build()
name = folder.name
cir = export_netlist(folder, name)
print(score(folder / f"{name}.kicad_sch").splitlines()[-1])
r = run_ac(cir, VEC)
f = r["f"]; w = 2 * np.pi * f
uc, u1, i = r["v(/u_c)"], r["v(/u_1)"], r["i(vs1)"]

# ---------------------------------------------------------- sign check on the back-EMF
scratch = LAB / "sim" / "_scratch"
scratch.mkdir(exist_ok=True)
def variant(gain, tag):
    txt = cir.read_text()
    txt2 = re.sub(r"^(E1 .*?) ([-\d.e]+)\s*$", lambda m: f"{m.group(1)} {gain}", txt, flags=re.M)
    assert txt2 != txt or gain == 1.5
    p = scratch / f"{name}_{tag}.cir"
    p.write_text(txt2)
    return run_ac(p, VEC)
r0 = variant(0, "noBEMF")
rneg = variant(-1.5, "flipped")
print("\n## Sign check (peak |u_c| in m/s per V)")
for tag, rr in (("Bl = +1.5 (as drawn)", r), ("Bl = 0 (no back-EMF)", r0), ("Bl = -1.5 (flipped)", rneg)):
    v = rr["v(/u_c)"]
    k = np.argmax(np.abs(v))
    print(f"  {tag:24s}: max|u_c| = {abs(v[k]):.4e} at {f[k]:.1f} Hz; |Z_E| at that f = {1/abs(rr['i(vs1)'][k]):.3f} ohm; DC current {abs(rr['i(vs1)'][0]):.3f} A")

# ---------------------------------------------------------- element table
print("\n## Element values")
for k, (v, unit, note) in L4.ELEMENTS.items():
    print(f"| {k} | {v:.4g} | {unit} | {note} |")
mr = L4.MMC * L4.MM1 / (L4.MMC + L4.MM1)
print("\n## Hand estimates")
print(f"  coil on C_ms against a fixed M_m1:  f = 1/(2 pi sqrt(M_mc C_ms))          = {1/(2*math.pi*math.sqrt(L4.MMC*L4.CMS)):.1f} Hz")
print(f"  same with the reduced mass {mr*1e3:.3f} g:  f = {1/(2*math.pi*math.sqrt(mr*L4.CMS)):.1f} Hz")
print(f"  both masses on C_ms2:  f = 1/(2 pi sqrt((M_mc+M_m1) C_ms2))               = {1/(2*math.pi*math.sqrt((L4.MMC+L4.MM1)*L4.CMS2)):.2f} Hz")
print(f"  M_m1 alone on C_ms2:   f = {1/(2*math.pi*math.sqrt(L4.MM1*L4.CMS2)):.2f} Hz")
print(f"  M_m1 on C_ms with the coil held (anti-resonance seen from the coil): f = 1/(2 pi sqrt(M_m1 C_ms)) = {1/(2*math.pi*math.sqrt(L4.MM1*L4.CMS)):.1f} Hz")
print(f"  M_m1 on C_ms||C_ms2 (series compliance) : {1/(2*math.pi*math.sqrt(L4.MM1*(L4.CMS*L4.CMS2/(L4.CMS+L4.CMS2)))):.1f} Hz")
print(f"  electrical damping (Bl)^2/Rc = {L4.BL**2/L4.RC:.2f} Ns/m ; electrical corner Rc/(2 pi Le) = {L4.RC/(2*math.pi*L4.LE):.0f} Hz")

# ---------------------------------------------------------- a) velocities
fig, ax = plt.subplots(2, 1, figsize=(8, 6.5), sharex=True)
ax[0].loglog(f, np.abs(uc), lw=1.6, label=r"coil $|u_c|$")
ax[0].loglog(f, np.abs(u1), lw=1.6, label=r"mass $|u_1|$")
ax[0].loglog(f, np.abs(r0["v(/u_c)"]), ":", lw=1, color="C0", label=r"coil, back-EMF removed ($Bl\to0$ in E1)")
ax[0].set_ylabel("velocity [m/s per V]"); ax[0].set_title("Part 4a — velocities of the coil and of $M_{m1}$, 1 V drive")
ax[0].grid(True, which="both", alpha=.3); ax[0].legend(fontsize=8)
ax[1].semilogx(f, deg(uc), lw=1.2, label=r"$\angle u_c$"); ax[1].semilogx(f, deg(u1), lw=1.2, label=r"$\angle u_1$")
ax[1].set_ylabel("phase [°]"); ax[1].set_xlabel("frequency [Hz]"); ax[1].grid(True, which="both", alpha=.3)
ax[1].legend(); ax[1].set_xlim(1, 1e4)
save_fig(fig, "part4a_velocities")
print("\n## a) velocities (per volt)")
for lab, v in (("u_c", uc), ("u_1", u1)):
    print(f"  {lab}: 1 Hz {abs(v[0]):.3e}, 10 kHz {abs(v[-1]):.3e}")
    for fr, m in peaks(f, v, "max", 1): print(f"     peak {fr:8.2f} Hz  {m:.4e} m/s")
    for fr, m in peaks(f, v, "min", 1): print(f"     dip  {fr:8.2f} Hz  {m:.4e} m/s")
ratio = u1 / uc
print("  |u_1/u_c| at 1 Hz %.3f, 5 Hz %.3f, 100 Hz %.3f, 700 Hz %.3f, 10 kHz %.3e" % tuple(abs(ratio[np.argmin(abs(f-x))]) for x in (1, 5, 100, 700, 1e4)))

# ---------------------------------------------------------- b) mechanical impedance
ZM = L4.BL * i / uc
fig, ax = plt.subplots(2, 1, figsize=(8, 6.5), sharex=True)
ax[0].loglog(f, np.abs(ZM), lw=1.6)
ax[0].set_ylabel(r"$|Z_M| = |f/u_c|$  [N·s/m]"); ax[0].set_title(r"Part 4b — mechanical input impedance seen by the force $f = Bl\,i$")
ax[0].grid(True, which="both", alpha=.3)
ax[1].semilogx(f, deg(ZM), lw=1.2, color="C1"); ax[1].set_ylabel("phase [°]"); ax[1].set_xlabel("frequency [Hz]")
ax[1].grid(True, which="both", alpha=.3); ax[1].set_xlim(1, 1e4); ax[1].set_yticks([-90, -45, 0, 45, 90])
save_fig(fig, "part4b_mechanical_impedance")
print("\n## b) Z_M = Bl*I(Vs1)/V(u_c)  [N s/m]")
print(f"  1 Hz {abs(ZM[0]):.3e}, 10 kHz {abs(ZM[-1]):.3e} (w M_mc = {w[-1]*L4.MMC:.1f})")
for fr, m in peaks(f, ZM, "min", 1): print(f"  resonance (min)      {fr:8.2f} Hz  {m:.4e}")
for fr, m in peaks(f, ZM, "max", 1): print(f"  anti-resonance (max) {fr:8.2f} Hz  {m:.4e}")

# ---------------------------------------------------------- c) electrical impedance
ZE = 1 / i
fig, ax = plt.subplots(2, 1, figsize=(8, 6.5), sharex=True)
ax[0].loglog(f, np.abs(ZE), lw=1.6, label=r"$|Z_E|$ complete system")
ax[0].loglog(f, np.abs(L4.RC + 1j * w * L4.LE), "--", lw=1.1, label=r"blocked coil $R_c + j\omega L_e$")
ax[0].loglog(f, np.abs(L4.BL**2 / ZM), ":", lw=1.1, label=r"motional part $(Bl)^2/Z_M$")
ax[0].set_ylabel(r"$|Z_E|$  [Ω]"); ax[0].set_title("Part 4c — electrical input impedance at the coil terminals")
ax[0].grid(True, which="both", alpha=.3); ax[0].legend(fontsize=8)
ax[1].semilogx(f, deg(ZE), lw=1.2, color="C1"); ax[1].set_ylabel("phase [°]"); ax[1].set_xlabel("frequency [Hz]")
ax[1].grid(True, which="both", alpha=.3); ax[1].set_xlim(1, 1e4); ax[1].set_yticks([-90, -45, 0, 45, 90])
save_fig(fig, "part4c_electrical_impedance")
print("\n## c) Z_E = 1/I(Vs1)  [ohm]")
print(f"  1 Hz {abs(ZE[0]):.4f}, 10 kHz {abs(ZE[-1]):.4f} (|Rc+jwLe| = {abs(L4.RC+1j*w[-1]*L4.LE):.4f})")
for fr, m in peaks(f, ZE, "max", 0.3): print(f"  peak {fr:8.2f} Hz  {m:.4f} ohm   (motional {m-L4.RC:.4f})")
for fr, m in peaks(f, ZE, "min", 0.3): print(f"  dip  {fr:8.2f} Hz  {m:.4f} ohm")

# combined overview for the discussion
fig, ax = plt.subplots(3, 1, figsize=(8, 9), sharex=True)
ax[0].loglog(f, np.abs(uc), label=r"$|u_c|$"); ax[0].loglog(f, np.abs(u1), label=r"$|u_1|$"); ax[0].set_ylabel("m/s per V"); ax[0].legend()
ax[1].loglog(f, np.abs(ZM)); ax[1].set_ylabel(r"$|Z_M|$ [N s/m]")
ax[2].loglog(f, np.abs(ZE)); ax[2].set_ylabel(r"$|Z_E|$ [Ω]"); ax[2].set_xlabel("frequency [Hz]")
for a in ax: a.grid(True, which="both", alpha=.3)
ax[0].set_title("Part 4 — resonances line up across the three plots"); ax[2].set_xlim(1, 1e4)
save_fig(fig, "part4_overview")
shutil.rmtree(scratch, ignore_errors=True)
