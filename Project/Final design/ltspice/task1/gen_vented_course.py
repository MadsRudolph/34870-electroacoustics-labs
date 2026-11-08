#!/usr/bin/env python3
"""Quiz part 1, Q5: the woofer box circuit in the lecture style (Louis's vented-box drawing),
with the agreed values from box_model.fit() and one vent at L = 160 mm.

    python3 gen_vented_course.py            # write Woofer_Vented_L160.asc/.plt
    python3 gen_vented_course.py --verify   # run LTspice headless, compare with box_model.system()
    python3 gen_vented_course.py --preview  # draw the schematic to preview/*.png

The drawing is ../../../ltspice/vented box/Vented_Box_26W8534G00_fixed.asc (Louis) unchanged in
geometry; only the values, the output gains and the comments are replaced, so the two files can be
laid side by side. Differences from Task1_WooferBox.asc (box_model's own circuit):
  - front radiation is the mass M_A1 only (no R_A1/R_A2/C_A1): < 0.1 dB below 200 Hz
  - "total" far field uses the current through C_AB (U_D - U_P - leak), as in Louis's file
  - the vent is one inductor M_AP = fitted mass for 160 mm, which already holds both end
    corrections, with R_AP as its series resistance (Louis had rho*L/S + a separate end mass)
"""
import math, pathlib, re, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
SRC = HERE.parents[2] / "ltspice" / "vented box" / "Vented_Box_26W8534G00_fixed.asc"
sys.path.insert(0, str(HERE.parents[3] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402
import box_model as bm                       # noqa: E402

NAME = "Woofer_Vented_L160"
L = 0.160


def values():
    drv, RAB, QL, QP, MAP, _ = bm.fit()
    box = bm.vent_box(RAB, QL, QP, MAP[L])
    MA1 = 8 * bm.RHO / (3 * math.pi ** 2 * bm.AD)
    return drv, box, MA1


def build(drv, box, MA1, plugged=False):
    """Louis's file with our values. plugged=True: the closed-box reference (vent mass 1e9)."""
    txt = SRC.read_bytes().decode("latin1")
    sd = f"{bm.SD:.5g}"
    kff = bm.RHO / (2 * math.pi * 20e-6)
    new = {
        "Le": (f"{drv['Le']*1e3:.4g}m", None),
        "HBLu": (f"Vd2 {drv['Bl']:.4g}", None),
        "HBLi": (f"Vd1 {drv['Bl']:.4g}", None),
        "Mmd": (f"{drv['Mmd']*1e3:.4g}m", None),
        "Rms": (f"{drv['Rms']:.4g}", None),
        "Cms": (f"{drv['Cms']*1e3:.5g}m", None),
        "ESdPd": (sd, None),
        "FSdud": (f"Vd2 {sd}", None),
        "Ma1f": (f"{MA1:.4g}", None),
        "Ral": (f"{(1e12 if plugged else box['RAL']):.5g}", None),
        "Cab": (f"{box['CAB']*1e6:.4g}u", None),
        "Map": ("1e9" if plugged else f"{box['MAP']:.4g}", f"Rser={box['RAP']:.4g}"),
        "Epd_Vent": (f"Laplace={kff:.5g}*s", None),
        "Epd_Diaph": (f"Laplace={kff:.5g}*s", None),
        "Epd_Total": (f"Laplace={kff:.5g}*s", None),
        "Enf_Vent": (f"Laplace={bm.RHO/(math.pi*bm.AP):.4g}*s", None),
        "Enf_Cone": (f"Laplace={bm.RHO/(math.pi*bm.AD):.4g}*s", None),
    }
    out, blocks, cur = [], [], None
    for ln in txt.splitlines():                       # group SYMBOL blocks so one can be dropped
        if ln.startswith("SYMBOL"):
            cur = [ln]; blocks.append(cur); out.append(cur); continue
        if cur is not None and (ln.startswith("WINDOW") or ln.startswith("SYMATTR")):
            cur.append(ln); continue
        cur = None; out.append(ln)
    lines = []
    for item in out:
        if isinstance(item, str):
            if item.startswith("TEXT") and (";" in item.split(" Left 2 ")[-1][:1] or ".step" in item):
                continue                              # Louis's notes and the length sweep
            lines.append(item); continue
        name = next(l.split()[2] for l in item if l.startswith("SYMATTR InstName"))
        if name == "Ma1p":                            # end mass is inside the fitted M_AP: short it
            lines.append("WIRE 2208 16 2288 16")
            continue
        for l in item:
            if name in new and l.startswith("SYMATTR Value "):
                l = "SYMATTR Value " + new[name][0]
            if name in new and new[name][1] and l.startswith("SYMATTR SpiceLine"):
                l = "SYMATTR SpiceLine " + new[name][1]
            lines.append(l)
    lines.insert(2, "FLAG 0 -64 eg")
    fb = bm.fb_of(box["MAP"])
    notes = [
        f"Woofer in the {bm.VB*1e3:.0f} L box, one vent open (L = {L*1e3:.0f} mm), filling in. Values fitted to our Lab D measurements."
        if not plugged else "Reference: the same circuit with both vents plugged (closed box).",
        "Top: electrical part (voice coil)  |  mechanical part (cone)  |  acoustical part (air in the box, the vent).",
        "Bottom: turns the air flows into sound pressure, far field at 1 m and near field.",
    ]
    lines += [f"TEXT 0 {800 + 40*k} Left 2 ;{n}" for k, n in enumerate(notes)]
    lines = [l.replace("SHEET 1 2600 1000", "SHEET 1 2600 1100") for l in lines]
    path = HERE / (f"{NAME}.asc" if not plugged else f"{NAME}_plugged.asc")
    path.write_text("\n".join(lines) + "\n")
    return path


def verify(asc, drv, box):
    d = g.run_ltspice(asc)
    f = np.array(d["frequency"]).real
    r = bm.system(f, drv, box)
    k = (f >= 5) & (f <= 200)
    ZE = np.array(d["v(eg)"]) / np.array(d["i(vd1)"])
    rows = [("Z_E", ZE, r["ZE"]),
            ("SPL total", np.array(d["v(db_spl_total)"]) * 20e-6, r["p1m"]),
            ("NF cone", np.array(d["v(nf_cone)"]), r["nf_cone"]),
            ("NF vent", np.array(d["v(nf_vent)"]), r["nf_vent"])]
    for lab, got, want in rows:
        e = np.max(np.abs(20 * np.log10(np.abs(got[k] / want[k]))))
        print(f"  {lab:10s} max |difference| 5-200 Hz: {e:.3f} dB")
    z = np.abs(ZE); band = (f > 8) & (f < 80); fb_i = np.argmin(np.where(band, z, 1e9))
    print(f"  impedance dip {f[fb_i]:.2f} Hz (measured 23.38 Hz), peaks "
          + ", ".join(f"{f[i]:.1f} Hz / {z[i]:.1f} ohm" for i in range(1, len(f) - 1)
                      if z[i] > z[i - 1] and z[i] > z[i + 1] and f[i] < 100))
    return d


if __name__ == "__main__":
    drv, box, MA1 = values()
    asc = build(drv, box, MA1)
    ref = build(drv, box, MA1, plugged=True)
    g.plt(HERE / f"{NAME}.plt", [(["V(dB_SPL_Diaph)", "V(dB_SPL_Vent)", "V(dB_SPL_Total)"], (1e3, 1e5))], (5, 1000))
    print("wrote", asc.name, "and", ref.name)
    if "--preview" in sys.argv:
        import preview_asc as pv
        pv.HERE = HERE
        pv.main(str(asc))
    if "--verify" in sys.argv:
        verify(asc, drv, box)
