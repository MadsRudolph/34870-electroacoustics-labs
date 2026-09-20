#!/usr/bin/env python3
"""Lab A Part 1 - dual-diaphragm loudspeaker, mechanical system only.

Builds two KiCad projects (stiff / soft link), exports them with kicad-cli,
runs ngspice, plots velocities and the mechanical input impedance, and prints
the extracted resonance numbers. Run from anywhere: python3 part1.py
"""
from __future__ import annotations

import math
import sys
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

sys.path.insert(0, str(Path(__file__).resolve().parent))
from common_p13 import (Sheet, KICAD, G, finish_project, export_netlist, run_ac,
                         save_fig, db, peaks, score)
import layouts_p13 as L

AC = ".ac dec 200 10 10k"
VECS = ["v(/u_vc)", "v(/u_d)"]


def build(variant: str) -> Path:
    name = f"Part1_DualDiaphragm_{variant}"
    sh = Sheet(paper="A4", title=f"Lab A Part 1 - Dual diaphragm, {variant} link",
               project=name)
    fields, _ = L.draw(sh, variant, radiation=False)
    sh.note((G(120), G(30)), "SPICE directive (read automatically, no workbook needed):", size=1.4)
    sh.note((G(120), G(34)), AC, size=1.8)
    return finish_project(sh, KICAD / name, name, fields, AC,
                          ["V(/u_vc)", "V(/u_d)", "1/V(/u_vc)"])


def simulate(variant: str) -> dict:
    sch = build(variant)
    print(score(sch).strip().splitlines()[-1] if score(sch).strip() else "")
    return run_ac(export_netlist(sch), VECS)


def analyse(tag, r):
    f = r["f"]
    uvc, ud = r["v(/u_vc)"], r["v(/u_d)"]
    Z = 1 / uvc
    out = {}
    for name, vec, kind in (("u_vc peaks", uvc, "max"), ("u_d peaks", ud, "max"),
                            ("u_vc dips", uvc, "min"),
                            ("|Z| minima (resonances)", Z, "min"),
                            ("|Z| maxima (anti-resonances)", Z, "max")):
        idx = peaks(f, np.abs(vec), kind)
        out[name] = [(float(f[i]), float(abs(vec[i]))) for i in idx]
    out["Z@10Hz"] = complex(Z[0]); out["Z@10kHz"] = complex(Z[-1])
    out["u_vc/u_d @10kHz"] = float(abs(uvc[-1] / ud[-1]))
    return out


def main():
    res = {v: simulate(v) for v in ("Stiff", "Soft")}
    f = res["Stiff"]["f"]

    # hand calculations
    C_tot = 1 / (1 / L.CMSP + 1 / L.CMSR)
    M_tot = L.MMD + L.MMVC
    f0_stiff = 1 / (2 * math.pi * math.sqrt(M_tot * C_tot))
    R_tot = L.RMSP + L.RMSR
    Q_stiff = math.sqrt(M_tot / C_tot) / R_tot
    print(f"hand: C_tot = {C_tot*1e3:.4f} mm/N, M_tot = {M_tot*1e3:.0f} g, "
          f"f0(stiff) = {f0_stiff:.2f} Hz, Q = {Q_stiff:.2f}, R_tot = {R_tot} Ns/m")
    # soft link: uncoupled sub-resonances for the explanation
    f_md_on_cmd = 1 / (2 * math.pi * math.sqrt(L.MMD * L.VARIANTS['Soft']['CMD']))
    print(f"hand: outer diaphragm on the soft link alone f = {f_md_on_cmd:.1f} Hz "
          f"(the u_vc dip / absorber frequency, approx)")

    numbers = {v: analyse(v, res[v]) for v in res}
    for v in numbers:
        print(f"--- {v}")
        for k, val in numbers[v].items():
            print(f"  {k}: {val}")

    # ---- Figure 1a: velocities, both cases ------------------------------------
    fig, ax = plt.subplots(2, 2, figsize=(11, 7), sharex=True)
    for j, v in enumerate(("Stiff", "Soft")):
        r = res[v]
        for key, lab, col in (("v(/u_vc)", "u_vc (voice coil + inner diaphragm)", "C0"),
                              ("v(/u_d)", "u_d (outer diaphragm)", "C3")):
            ax[0, j].semilogx(f, db(r[key]), col, label=lab)
            ax[1, j].semilogx(f, np.degrees(np.angle(r[key])), col, label=lab)
        ax[0, j].set_title(f"{v} link: C_md = {L.VARIANTS[v]['CMD']:g} m/N, R_md = {L.VARIANTS[v]['RMD']:g} Ns/m")
        ax[0, j].set_ylabel("|u| / dB re 1 (m/s)/N"); ax[1, j].set_ylabel("phase / deg")
        ax[1, j].set_xlabel("frequency / Hz")
        for a in ax[:, j]:
            a.grid(True, which="both", alpha=.3); a.legend(fontsize=8)
        ax[0, j].set_ylim(-70, 10); ax[1, j].set_ylim(-270, 100)
    fig.suptitle("Part 1a - velocity response to F = 1 N")
    save_fig(fig, "part1a_velocities.png")

    # ---- Figure 1b: mechanical input impedance ---------------------------------
    fig, ax = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
    for v, col in (("Stiff", "C0"), ("Soft", "C3")):
        Z = 1 / res[v]["v(/u_vc)"]
        ax[0].loglog(f, np.abs(Z), col, label=f"{v} link")
        ax[1].semilogx(f, np.degrees(np.angle(Z)), col, label=f"{v} link")
    ax[0].loglog(f, 2 * math.pi * f * M_tot, "k:", lw=1, label="mass line ωM_tot (11 g)")
    ax[0].loglog(f, 1 / (2 * math.pi * f * C_tot), "k--", lw=1, label="compliance line 1/(ωC_tot)")
    ax[0].set_ylabel("|Z_M| / Ns/m"); ax[1].set_ylabel("phase / deg"); ax[1].set_xlabel("frequency / Hz")
    ax[0].set_ylim(0.3, 1e3); ax[1].set_ylim(-100, 100)
    for a in ax: a.grid(True, which="both", alpha=.3); a.legend(fontsize=8)
    fig.suptitle("Part 1b - mechanical input impedance Z_M = F / u_vc")
    save_fig(fig, "part1b_impedance.png")

    # ---- Figure: velocity ratio (how well the outer cone follows) -------------
    fig, ax = plt.subplots(figsize=(9, 4))
    for v, col in (("Stiff", "C0"), ("Soft", "C3")):
        ax.semilogx(f, db(res[v]["v(/u_d)"] / res[v]["v(/u_vc)"]), col, label=f"{v} link")
    ax.set_ylabel("|u_d / u_vc| / dB"); ax.set_xlabel("frequency / Hz"); ax.grid(True, which="both", alpha=.3)
    ax.legend(); ax.set_title("Part 1 - outer diaphragm velocity relative to the voice coil")
    save_fig(fig, "part1_velocity_ratio.png")

    np.savez(Path(__file__).with_name("part1_data.npz"), f=f,
             **{f"{v}_{k.strip('v(/)')}": res[v][k] for v in res for k in VECS})
    return numbers, dict(C_tot=C_tot, M_tot=M_tot, f0_stiff=f0_stiff, Q_stiff=Q_stiff,
                         f_md_on_cmd=f_md_on_cmd)


if __name__ == "__main__":
    main()
