#!/usr/bin/env python3
"""Shared helpers for the Lab A KiCad -> ngspice pipeline.

Every part script does the same four things: draw the schematic with schdraw,
write the project/workbook files so KiCad opens it ready to Run, export the
SPICE netlist with kicad-cli, and run ngspice in batch with wrdata. This
module holds the boring parts of that so the part scripts read as physics.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

import numpy as np

SKILL = "/home/mads/.claude/skills/kicad-schematic/scripts"
if SKILL not in sys.path:
    sys.path.insert(0, SKILL)

REPO = Path("/home/mads/DTU")
LAB = REPO / "5. Semester/Electroacoustics/Labs/Lab A"
KICAD_DIR = LAB / "KiCad"
FIG_DIR = LAB / "figures"
RES_DIR = LAB / "results"
VAULT_IMG = REPO / "Obsidian/Courses/34870 Electroacoustics/Images/LabA"

RHO = 1.18      # kg/m^3
C0 = 344.0      # m/s

G = lambda n: round(n * 1.27, 2)   # one KiCad grid step


def ctrl(kind: str, gain) -> dict:
    """Sim fields for an ESOURCE/GSOURCE instance. The escaped quotes are
    mandatory -- raw quotes corrupt the s-expression."""
    return {"Sim.Device": "SPICE",
            "Sim.Params": 'type=\\"%s\\" model=\\"%s\\"' % (kind, fmt(gain))}


def vsrc(params="dc=0 ac=1") -> dict:
    return {"Sim.Device": "V", "Sim.Type": "DC", "Sim.Pins": "1=+ 2=-",
            "Sim.Params": params}


def isrc(params="dc=0 ac=1") -> dict:
    return {"Sim.Device": "I", "Sim.Type": "DC", "Sim.Pins": "1=+ 2=-",
            "Sim.Params": params}


def fmt(x) -> str:
    """SPICE-friendly number string (no 'M' ambiguity: use e-notation)."""
    if isinstance(x, str):
        return x
    return "%.6g" % x


def write_project(folder: Path, name: str, sheet_uuid: str) -> None:
    pro = {
        "board": {"design_settings": {"defaults": {}, "diff_pair_dimensions": [],
                                      "drc_exclusions": [], "rules": {},
                                      "track_widths": [], "via_dimensions": []}},
        "boards": [],
        "libraries": {"pinned_footprint_libs": [], "pinned_symbol_libs": []},
        "meta": {"filename": f"{name}.kicad_pro", "version": 1},
        "net_settings": {
            "classes": [{
                "bus_width": 12, "clearance": 0.2, "diff_pair_gap": 0.25,
                "diff_pair_via_gap": 0.25, "diff_pair_width": 0.2, "line_style": 0,
                "microvia_diameter": 0.3, "microvia_drill": 0.1, "name": "Default",
                "pcb_color": "rgba(0, 0, 0, 0.000)", "priority": 2147483647,
                "schematic_color": "rgba(0, 0, 0, 0.000)", "track_width": 0.25,
                "via_diameter": 0.8, "via_drill": 0.4, "wire_width": 6}],
            "meta": {"version": 4}, "net_colors": None,
            "netclass_assignments": None, "netclass_patterns": []},
        "pcbnew": {"page_layout_descr_file": ""},
        "schematic": {"meta": {"version": 1},
                      "ngspice": {"meta": {"version": 0}, "fix_include_paths": True,
                                  "fix_passive_vals": False, "model_mode": 4,
                                  "workbook_filename": f"{name}.wbk"}},
        "sheets": [[sheet_uuid, "Root"]],
        "text_variables": {},
    }
    (folder / f"{name}.kicad_pro").write_text(json.dumps(pro, indent=2) + "\n")


PALETTE = ["rgb(228, 26, 28)", "rgb(55, 126, 184)", "rgb(77, 175, 74)",
           "rgb(152, 78, 163)", "rgb(255, 127, 0)", "rgb(166, 86, 40)"]


def write_ac_workbook(folder: Path, name: str, command: str, signals,
                      phase_for=()) -> None:
    """AC workbook: gain traces (521) for every signal, phase (517) for the
    ones listed in phase_for. Expressions become user-defined signals."""
    import re
    plain = re.compile(r"^[VI]\(/?[A-Za-z0-9_+.\-]+\)$")
    traces = []
    for i, s in enumerate(signals):
        traces.append({"color": PALETTE[i % len(PALETTE)],
                       "signal": f"{s} (gain)", "trace_type": 521})
        if s in phase_for:
            traces.append({"color": PALETTE[i % len(PALETTE)],
                           "signal": f"{s} (phase)", "trace_type": 517})
    wb = {
        "custom_cursors": 2,
        "last_sch_text_sim_command": command,
        "tabs": [{
            "analysis": "AC",
            "commands": [command, ".kicad adjustpaths", ".save all",
                         ".probe alli", ".probe allp"],
            "dottedSecondary": False,
            "margins": {"bottom": 45, "left": 70, "right": 70, "top": 30},
            "measurements": [], "showGrid": True, "traces": traces}],
        "user_defined_signals": [s for s in signals if not plain.match(s)],
        "version": 7,
    }
    (folder / f"{name}.wbk").write_text(json.dumps(wb, indent=2) + "\n")


def export_netlist(folder: Path, name: str) -> Path:
    sch = folder / f"{name}.kicad_sch"
    cir = folder / f"{name}.cir"
    subprocess.run(["kicad-cli", "sch", "export", "netlist", "--format", "spice",
                    "-o", str(cir), str(sch)], check=True,
                   capture_output=True, text=True, encoding="utf-8")
    return cir


def run_ac(cir: Path, vectors, workdir: Path | None = None, extra_control: str = "") -> dict:
    """Run the exported deck in batch ngspice and return {vector: complex array}
    plus 'f' (Hz). The .ac line inside the deck is used as-is."""
    workdir = workdir or cir.parent
    out = workdir / (cir.stem + "_ac.txt")
    drv = workdir / (cir.stem + "_run.cir")
    vec = " ".join(vectors)
    drv.write_text(
        f"* batch driver for {cir.name}\n.include {cir.name}\n.control\nrun\n"
        f"{extra_control}\nset wr_vecnames\nset wr_singlescale\n"
        f"wrdata {out.name} {vec}\nquit\n.endc\n.end\n")
    r = subprocess.run(["ngspice", "-b", str(drv)], capture_output=True,
                       text=True, encoding="utf-8", cwd=workdir)
    if r.returncode != 0 or not out.exists():
        raise RuntimeError("ngspice failed:\n" + r.stdout + r.stderr)
    return parse_wrdata(out, vectors)


def parse_wrdata(path: Path, vectors) -> dict:
    """wr_singlescale + wr_vecnames: header line, then freq, re, im per vector."""
    lines = path.read_text().strip().splitlines()
    header = lines[0].split()
    data = np.array([[float(x) for x in ln.split()] for ln in lines[1:]])
    res = {"f": data[:, 0]}
    col = 1
    for v in vectors:
        res[v] = data[:, col] + 1j * data[:, col + 1]
        col += 2
    return res


def db(x):
    return 20 * np.log10(np.abs(x))


def deg(x):
    return np.degrees(np.unwrap(np.angle(x)))


def save_fig(fig, name: str) -> Path:
    FIG_DIR.mkdir(parents=True, exist_ok=True)
    VAULT_IMG.mkdir(parents=True, exist_ok=True)
    p = FIG_DIR / f"{name}.png"
    fig.savefig(p, dpi=150, bbox_inches="tight")
    shutil.copy(p, VAULT_IMG / p.name)
    return p


def peaks(f, mag, kind="max", min_prom_db=1.0):
    """Local maxima (or minima) of |mag| in dB with a crude prominence test."""
    m = db(mag)
    if kind == "min":
        m = -m
    idx = []
    for i in range(1, len(m) - 1):
        if m[i] > m[i - 1] and m[i] >= m[i + 1]:
            lo = max(0, i - 40); hi = min(len(m), i + 40)
            if m[i] - min(m[lo:i].min(), m[i + 1:hi].min()) >= min_prom_db:
                idx.append(i)
    return [(f[i], np.abs(mag[i])) for i in idx]


def score(sch: Path) -> str:
    r = subprocess.run([sys.executable, f"{SKILL}/sch_score.py", str(sch)],
                       capture_output=True, text=True, encoding="utf-8")
    return r.stdout + r.stderr
