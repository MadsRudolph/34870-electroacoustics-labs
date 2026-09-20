#!/usr/bin/env python3
"""Lab A Part 3 - dual-diaphragm loudspeaker with baffled radiation loading on
both sides of both diaphragms. Builds Part3_Coupled_{Stiff,Soft}, re-runs the
Part 1 decks for the overlay, plots velocities / impedance / pressures and
prints the numbers. Run from anywhere: python3 part3.py
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
from common_p13 import (Sheet, KICAD, G, RHO, C0, finish_project, export_netlist,
                         run_ac, save_fig, db, peaks, score)
import layouts_p13 as L
import part1

AC = ".ac dec 200 10 10k"
VECS = ["v(/u_vc)", "v(/u_d)", "v(/p_i)", "v(/p_o)"]


def build(variant: str):
    name = f"Part3_Coupled_{variant}"
    sh = Sheet(paper="A4", title=f"Lab A Part 3 - Dual diaphragm + radiation, {variant} link",
               project=name)
    fields, vals = L.draw(sh, variant, radiation=True)
    sh.note((G(150), G(30)), "SPICE directive (read automatically, no workbook needed):", size=1.4)
    sh.note((G(150), G(34)), AC, size=1.8)
    sch = finish_project(sh, KICAD / name, name, fields, AC,
                         ["V(/u_vc)", "V(/u_d)", "V(/p_i)/2", "V(/p_o)/2"])
    return sch, vals


def main():
    p1 = {v: part1.simulate(v) for v in ("Stiff", "Soft")}
    p3, vals = {}, None
    for v in ("Stiff", "Soft"):
        sch, vals = build(v)
        sc = score(sch)
        print(sc.strip().splitlines()[0])
        bad = [ln for ln in sc.splitlines() if "FAIL" in ln]
        if bad:
            print("\n".join(bad))
        p3[v] = run_ac(export_netlist(sch), VECS)
    f = p3["Stiff"]["f"]

    # ---- hand numbers for the explanation ------------------------------------
    print("\n=== radiation-load hand numbers (per side / both sides) ===")
    for tag, S in (("inner", L.S_I), ("outer", L.S_O)):
        r = vals[f"rad_{'i' if tag=='inner' else 'o'}"]
        a = r["a"]
        m_add = 2 * S * S * r["MA1_1"]            # kg, both sides
        r_hf = 2 * S * S * r["RA2_1"]             # Ns/m, both sides, ka >> 1
        f_ka1 = C0 / (2 * math.pi * a)
        print(f"{tag}: a = {a*1e3:.1f} mm  per side M_A1 = {r['MA1_1']:.3f} kg/m4, "
              f"R_A1 = {r['RA1_1']:.0f}, R_A2 = {r['RA2_1']:.0f} Pa s/m3, C_A1 = {r['CA1_1']:.3e} m5/N")
        print(f"       both sides in SPICE: L = {r['MA1']:.3f}, R_A2 = {r['RA2']:.0f}, "
              f"R_A1 = {r['RA1']:.0f}, C = {r['CA1']:.3e}")
        print(f"       added mass 2S^2 M_A1 = {m_add*1e3:.3f} g, HF resistance 2S^2 R_A2 = {r_hf:.2f} Ns/m, "
              f"ka = 1 at {f_ka1:.0f} Hz")

    # ---- extracted numbers ------------------------------------------------------
    numbers = {}
    for v in ("Stiff", "Soft"):
        n1, n3 = part1.analyse(v, p1[v]), part1.analyse(v, p3[v])
        numbers[v] = {"part1": n1, "part3": n3}
        print(f"\n--- {v}: Part 1 -> Part 3")
        for k in n1:
            print(f"  {k}:\n     P1 {n1[k]}\n     P3 {n3[k]}")
        pi, po = p3[v]["v(/p_i)"] / 2, p3[v]["v(/p_o)"] / 2
        for lab, vec in (("p_front inner", pi), ("p_front outer", po)):
            idx = peaks(f, np.abs(vec), "max")
            print(f"  {lab} peaks: {[(round(float(f[i]),1), round(float(abs(vec[i])),2)) for i in idx]}"
                  f"  @10kHz {abs(vec[-1]):.2f} Pa/N")
        U = L.S_I * p3[v]["v(/u_vc)"] + L.S_O * p3[v]["v(/u_d)"]
        pff = 1j * 2 * math.pi * f * RHO * U / (2 * math.pi * 1.0)
        numbers[v]["pff"] = pff
        idx = peaks(f, np.abs(pff), "max")
        print(f"  far-field p(1 m) peaks: {[(round(float(f[i]),1), round(float(abs(pff[i])),3)) for i in idx]}"
              f"  @1kHz {abs(pff[np.argmin(abs(f-1000))]):.3f}  @10kHz {abs(pff[-1]):.3f} Pa/N")

    # ---- Figure 3a: velocities, Part 1 vs Part 3 -------------------------------
    fig, ax = plt.subplots(2, 2, figsize=(11, 7), sharex=True)
    for j, v in enumerate(("Stiff", "Soft")):
        for key, lab, col in (("v(/u_vc)", "u_vc", "C0"), ("v(/u_d)", "u_d", "C3")):
            ax[0, j].semilogx(f, db(p1[v][key]), col, ls="--", lw=1, label=f"{lab} Part 1 (no air load)")
            ax[0, j].semilogx(f, db(p3[v][key]), col, label=f"{lab} Part 3 (radiation both sides)")
            ax[1, j].semilogx(f, np.degrees(np.angle(p1[v][key])), col, ls="--", lw=1)
            ax[1, j].semilogx(f, np.degrees(np.angle(p3[v][key])), col)
        ax[0, j].set_title(f"{v} link"); ax[0, j].set_ylim(-70, 10); ax[1, j].set_ylim(-270, 100)
        ax[0, j].set_ylabel("|u| / dB re 1 (m/s)/N"); ax[1, j].set_ylabel("phase / deg")
        ax[1, j].set_xlabel("frequency / Hz")
        for a in ax[:, j]: a.grid(True, which="both", alpha=.3)
        ax[0, j].legend(fontsize=7)
    fig.suptitle("Part 3a - velocities with and without the radiation load (F = 1 N)")
    save_fig(fig, "part3a_velocities.png")

    # ---- Figure 3a': impedance ---------------------------------------------------
    fig, ax = plt.subplots(2, 1, figsize=(9, 7), sharex=True)
    for v, col in (("Stiff", "C0"), ("Soft", "C3")):
        Z1, Z3 = 1 / p1[v]["v(/u_vc)"], 1 / p3[v]["v(/u_vc)"]
        ax[0].loglog(f, abs(Z1), col, ls="--", lw=1, label=f"{v} Part 1")
        ax[0].loglog(f, abs(Z3), col, label=f"{v} Part 3")
        ax[1].semilogx(f, np.degrees(np.angle(Z1)), col, ls="--", lw=1)
        ax[1].semilogx(f, np.degrees(np.angle(Z3)), col)
    ax[0].set_ylabel("|Z_M| / Ns/m"); ax[1].set_ylabel("phase / deg"); ax[1].set_xlabel("frequency / Hz")
    ax[0].set_ylim(0.3, 1e3); ax[1].set_ylim(-100, 100)
    for a in ax: a.grid(True, which="both", alpha=.3)
    ax[0].legend(fontsize=8)
    fig.suptitle("Part 3a - mechanical input impedance Z_M = F / u_vc, with and without air load")
    save_fig(fig, "part3a_impedance.png")

    # ---- Figure 3b: pressures ---------------------------------------------------
    fig, ax = plt.subplots(1, 2, figsize=(12, 4.5), sharey=True)
    for j, v in enumerate(("Stiff", "Soft")):
        pi, po = p3[v]["v(/p_i)"] / 2, p3[v]["v(/p_o)"] / 2
        ax[j].semilogx(f, db(pi), "C0", label="p in front of inner diaphragm (60 cm²)")
        ax[j].semilogx(f, db(po), "C3", label="p in front of outer diaphragm (210 cm²)")
        ax[j].semilogx(f, db(numbers[v]["pff"]), "k", lw=1.2, label="far field, 1 m on axis, half space, U_i + U_o")
        ax[j].set_title(f"{v} link"); ax[j].set_xlabel("frequency / Hz"); ax[j].grid(True, which="both", alpha=.3)
        ax[j].legend(fontsize=7)
    ax[0].set_ylabel("|p| / dB re 1 Pa/N"); ax[0].set_ylim(-60, 40)
    fig.suptitle("Part 3b - sound pressure per newton of coil force")
    save_fig(fig, "part3b_pressures.png")

    # ---- Figure: contribution of each diaphragm to the far field (soft) -------
    fig, ax = plt.subplots(figsize=(9, 4.5))
    v = "Soft"
    Ui = L.S_I * p3[v]["v(/u_vc)"]; Uo = L.S_O * p3[v]["v(/u_d)"]
    k = 1j * 2 * math.pi * f * RHO / (2 * math.pi)
    ax.semilogx(f, db(k * Ui), "C0", label="inner diaphragm alone")
    ax.semilogx(f, db(k * Uo), "C3", label="outer diaphragm alone")
    ax.semilogx(f, db(k * (Ui + Uo)), "k", label="sum (what the listener gets)")
    ax.set_xlabel("frequency / Hz"); ax.set_ylabel("|p(1 m)| / dB re 1 Pa/N"); ax.set_ylim(-60, 20)
    ax.grid(True, which="both", alpha=.3); ax.legend(fontsize=8)
    ax.set_title("Part 3b - soft link: who radiates where (far field, 1 m, half space)")
    save_fig(fig, "part3b_farfield_split.png")

    np.savez(Path(__file__).with_name("part3_data.npz"), f=f,
             **{f"{v}_{k.strip('v(/)')}": p3[v][k] for v in p3 for k in VECS})


if __name__ == "__main__":
    main()
