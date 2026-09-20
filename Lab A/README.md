# 34870 Lab A — Analogy circuits (KiCad 10 + ngspice 47)

Everything the lab asks for, done with KiCad schematics and batch ngspice instead of LTspice.
The physics and the plots are identical; the quiz translation to LTspice is in the vault note
`Obsidian/Courses/34870 Electroacoustics/Labs/Lab A - Runthrough.md`.

| Folder | What |
|---|---|
| `KiCad/PartN_*/` | One KiCad project per circuit: `.kicad_sch` (with the `.ac` directive as sheet text, so Inspect → Simulator → Run just works), `.kicad_pro`, `.wbk` (traces preloaded), exported `.cir` netlist |
| `sim/partN.py` | Regenerates the schematic(s), exports the netlist with `kicad-cli`, runs `ngspice -b`, post-processes with numpy, writes the figures and prints the extracted numbers. Run from any cwd. |
| `sim/common_p13.py`, `layouts_p13.py` | Helpers + layout for Parts 1 and 3 (dual diaphragm, with/without radiation) |
| `sim/common_p24.py`, `part2_layout.py`, `part4_layout.py` | Helpers + layouts for Parts 2 (silencer) and 4 (coil) |
| `figures/` | All plots (also copied to the vault `Images/LabA/`) |
| `results/partN.md` | Element tables, extracted numbers, interpretation per sub-question |
| `report/LabA_report.tex` | LaTeX write-up; compile with `~/.local/bin/tectonic LabA_report.tex` (tectonic fetches packages on first run) |

Conventions: mechanical parts in the **mobility** analogy (u ↔ V, f ↔ I, M → C, C_m → L, R_m → 1/R),
acoustic parts in the **impedance** analogy (p ↔ V, U ↔ I, M_A → L, C_A → C to ground, R_A → R).
Couplings use KiCad `GSOURCE`/`ESOURCE` (VCCS/VCVS). Instance fields must be
`Sim.Device=SPICE`, `Sim.Params=type=\"G\" model=\"<gain>\"` (escaped quotes inside the file);
current of a G source flows from N+ through the source to N−.
