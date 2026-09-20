#!/usr/bin/env python3
"""Shared helpers for the Lab A KiCad/ngspice simulations.

Everything here is tool plumbing: emitting a .kicad_pro next to a schematic
written by schdraw, stamping Sim.* fields onto sources, exporting the SPICE
netlist with kicad-cli, running ngspice in batch and reading `wrdata` output.
The physics lives in the per-part scripts.
"""
from __future__ import annotations

import json
import shutil
import subprocess
import sys
import uuid
from pathlib import Path

import numpy as np

SKILL = "/home/mads/.claude/skills/kicad-schematic/scripts"
sys.path.insert(0, SKILL)
from schdraw import Sheet  # noqa: E402,F401
from simfields import set_sim, write_workbook  # noqa: E402,F401

REPO = Path("/home/mads/DTU")
LAB = REPO / "5. Semester/Electroacoustics/Labs/Lab A"
KICAD = LAB / "KiCad"
FIG = LAB / "figures"
RESULTS = LAB / "results"
VAULT_IMG = REPO / "Obsidian/Courses/34870 Electroacoustics/Images/LabA"

RHO = 1.18   # kg/m^3
C0 = 344.0   # m/s

G = lambda n: round(n * 1.27, 2)  # noqa: E731  one KiCad grid step


def topbot(part):
    a, b = part.pin(1), part.pin(2)
    top = a if a.y < b.y else b
    bot = b if top is a else a
    return top, bot


def ctrl(kind: str, gain) -> dict:
    """Sim fields for a KiCad ESOURCE/GSOURCE instance. The escaped quotes
    are mandatory: raw quotes corrupt the .kicad_sch."""
    return {"Sim.Device": "SPICE",
            "Sim.Params": 'type=\\"%s\\" model=\\"%s\\"' % (kind, fmt(gain))}


def isrc(ac=1) -> dict:
    return {"Sim.Device": "I", "Sim.Type": "DC", "Sim.Pins": "1=+ 2=-",
            "Sim.Params": f"dc=0 ac={ac}"}


def vsrc(ac=1, dc=0) -> dict:
    return {"Sim.Device": "V", "Sim.Type": "DC", "Sim.Pins": "1=+ 2=-",
            "Sim.Params": f"dc={dc} ac={ac}"}


def fmt(x) -> str:
    """SPICE-friendly number: 1.3m, 4.545, 14.59, 1.775n ..."""
    if isinstance(x, str):
        return x
    x = float(x)
    if x == 0:
        return "0"
    for exp, suf in ((9, "G"), (6, "Meg"), (3, "k"), (0, ""), (-3, "m"),
                     (-6, "u"), (-9, "n"), (-12, "p"), (-15, "f")):
        if abs(x) >= 10 ** exp:
            v = x / 10 ** exp
            s = f"{v:.4g}"
            return s + suf
    return f"{x:.4g}"


def write_pro(folder: Path, name: str, sheet_uuid: str) -> None:
    pro = {
        "board": {"design_settings": {"defaults": {}, "diff_pair_dimensions": [],
                                      "drc_exclusions": [], "rules": {},
                                      "track_widths": [], "via_dimensions": []}},
        "boards": [],
        "libraries": {"pinned_footprint_libs": [], "pinned_symbol_libs": []},
        "meta": {"filename": f"{name}.kicad_pro", "version": 1},
        "net_settings": {
            "classes": [{"bus_width": 12, "clearance": 0.2, "diff_pair_gap": 0.25,
                         "diff_pair_via_gap": 0.25, "diff_pair_width": 0.2,
                         "line_style": 0, "microvia_diameter": 0.3,
                         "microvia_drill": 0.1, "name": "Default",
                         "pcb_color": "rgba(0, 0, 0, 0.000)",
                         "priority": 2147483647,
                         "schematic_color": "rgba(0, 0, 0, 0.000)",
                         "track_width": 0.25, "via_diameter": 0.8,
                         "via_drill": 0.4, "wire_width": 6}],
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
    (folder / f"{name}.kicad_pro").write_text(json.dumps(pro, indent=2) + "\n",
                                              encoding="utf-8")


def finish_project(sh: Sheet, folder: Path, name: str, sim_fields: dict,
                   command: str, signals) -> Path:
    """emit + stamp Sim fields + .pro + .wbk; returns the .kicad_sch path."""
    folder.mkdir(parents=True, exist_ok=True)
    problems = sh.check()
    if problems:
        raise SystemExit(f"{name}: sh.check() -> {problems}")
    sch = folder / f"{name}.kicad_sch"
    sh.emit(str(sch))
    set_sim(sch, sim_fields)
    write_pro(folder, name, sh.uuid)
    write_workbook(folder / f"{name}.wbk", command, signals)
    # write_workbook defaults to a TRAN tab; this lab is all AC sweeps.
    wb = json.loads((folder / f"{name}.wbk").read_text(encoding="utf-8"))
    wb["tabs"][0]["analysis"] = "AC"
    (folder / f"{name}.wbk").write_text(json.dumps(wb, indent=2) + "\n",
                                        encoding="utf-8")
    return sch


def export_netlist(sch: Path) -> Path:
    cir = sch.with_suffix(".cir")
    subprocess.run(["kicad-cli", "sch", "export", "netlist", "--format", "spice",
                    "-o", str(cir), str(sch)], check=True,
                   capture_output=True, text=True, encoding="utf-8")
    return cir


def run_ac(cir: Path, vectors, workdir: Path | None = None) -> dict:
    """Run the exported deck in ngspice batch mode; return {name: complex array}
    plus 'f'. `vectors` are ngspice expressions like 'v(/u_vc)' or 'i(Vs1)'."""
    workdir = workdir or cir.parent
    out = workdir / (cir.stem + "_ac.txt")
    deck = workdir / (cir.stem + "_run.cir")
    vec = " ".join(vectors)
    # paths carry spaces ("5. Semester/...") -> run with cwd=workdir and bare names
    deck.write_text(
        f".include {cir.name}\n.control\nset wr_singlescale\nset wr_vecnames\n"
        f"run\nwrdata {out.name} {vec}\nquit\n.endc\n.end\n", encoding="utf-8")
    r = subprocess.run(["ngspice", "-b", deck.name], capture_output=True,
                       text=True, encoding="utf-8", cwd=str(workdir))
    if r.returncode != 0 or not out.exists():
        raise SystemExit(f"ngspice failed for {cir}:\n{r.stdout}\n{r.stderr}")
    lines = out.read_text(encoding="utf-8").strip().splitlines()
    header = lines[0].split()
    data = np.array([[float(x) for x in ln.split()] for ln in lines[1:]])
    res = {"f": data[:, 0]}
    # with wr_singlescale a complex vector occupies two columns: re, im
    col = 1
    for name in vectors:
        res[name] = data[:, col] + 1j * data[:, col + 1]
        col += 2
    assert col == data.shape[1], (header, data.shape)
    return res


def save_fig(fig, name: str) -> None:
    FIG.mkdir(parents=True, exist_ok=True)
    VAULT_IMG.mkdir(parents=True, exist_ok=True)
    p = FIG / name
    fig.savefig(p, dpi=150, bbox_inches="tight")
    shutil.copy(p, VAULT_IMG / name)
    print("wrote", p)


def db(x):
    return 20 * np.log10(np.abs(x))


def peaks(f, mag, kind="max"):
    """Indices of local maxima (or minima) of a 1-D magnitude array."""
    m = np.asarray(mag)
    if kind == "min":
        m = -m
    idx = [i for i in range(1, len(m) - 1) if m[i] > m[i - 1] and m[i] >= m[i + 1]]
    return idx


def score(sch: Path) -> str:
    r = subprocess.run([sys.executable, f"{SKILL}/sch_score.py", str(sch)],
                       capture_output=True, text=True, encoding="utf-8")
    return r.stdout + r.stderr
