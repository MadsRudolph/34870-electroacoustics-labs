#!/usr/bin/env python3
"""Ready-to-use LTspice files for the project, all reading ../data (from export_systemD.m).

    python3 gen_templates.py            # write units/Unit_{woof,mid,tw}.asc and System_template.asc
    python3 gen_templates.py --verify   # run LTspice headless: each unit must reproduce Lab D Z and Lab E p/V

units/Unit_<u>.asc   The course file Loudspeaker_with_measurement_files.asc with our data in it,
                     names made unique (Vspkr_mid, Pout_mid, ...). No filter yet: this is the
                     guide's check "LTspice reproduces the measured Zi and TF" (work plan step 2.1).
                     V(Pout_<u>) = on axis, V(Pout30_<u>) = 30 deg. The woofer has no Zi (digital branch).
System_template.asc  Figure 1 of the guide as an empty skeleton: Vin -> two E biquad slots -> woofer,
                     Vin -> two E biquad slots -> Vhp -> [passive LPF] -> midrange, Vhp -> [passive HPF]
                     -> tweeter, and the sum of the three outputs as series E sources (gain/polarity
                     as .params). The biquad slots hold gain 1 and the passive slots are plain wires,
                     so it runs as it is and shows the unfiltered sum. Paste the DigitalCrossover.m
                     strings into the E slots and replace the wires with the filters.
"""
import cmath, math, os, pathlib, shutil, subprocess, sys, tempfile
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
DATA = HERE.parent / "data"
COURSE = HERE / "course" / "passive" / "Loudspeaker_with_measurement_files.asc"
sys.path.insert(0, str(HERE.parents[1] / "Lab A" / "LTspice"))
import gen_ltspice as g                      # noqa: E402

UNITS = {"woof": "woofer", "mid": "midrange", "tw": "tweeter"}
D, C_PU = -1.15, 345.0                       # Matlab2LTspice distance and phaseunwrap's c


# ---------------------------------------------------------------- unit files
def unit(u):
    s = COURSE.read_text(errors="ignore").replace("\r\n", "\n")
    rep = [("FLAG -224 64 Vin", f"FLAG -224 64 Vin_{u}"), ("FLAG 512 64 Vspkr", f"FLAG 512 64 Vspkr_{u}"),
           ("FLAG 736 64 Pout", f"FLAG 736 64 Pout_{u}"), ("InstName V1", f"InstName V_{u}"),
           ("InstName R1", f"InstName R_{u}"), ("InstName Yi", f"InstName Yi_{u}"),
           ("!.inc TF_data.txt", f"!.inc ../../data/TF_{u}.txt"),
           ("!.ac dec 1000 20 20000", "!.ac dec 200 20 20000")]
    rep.append(("!.inc Zi_data.txt", ";.inc Zi not used: the woofer is driven by the amplifier directly" if u == "woof"
                else f"!.inc ../../data/Zi_{u}.txt"))
    for a, b in rep:
        assert a in s, a
        s = s.replace(a, b)
    s += (f"TEXT 672 -32 Left 2 !.inc ../../data/TF30_{u}.txt\n"
          f"TEXT -224 -96 Left 2 ;System D {UNITS[u]}, measured data from Project/data (export_systemD.m). "
          f"V(Pout_{u}) = Lab E p/V on axis, V(Pout30_{u}) = 30 deg (both distance-compensated, d = {D} m).\\n"
          + (f"Check: V(Vspkr_{u})/I(Yi_{u}) must equal the Lab D impedance, and V(Pout_{u}) the Lab E response."
             if u != "woof" else "Check: V(Pout_woof) must equal the Lab E response (vent plugged). No Zi: the woofer branch has no passive filter.")
          + "\n")
    out = HERE / "units" / f"Unit_{u}.asc"
    out.parent.mkdir(exist_ok=True)
    out.write_text(s)
    traces = [(["V(Pout_%s)" % u, "V(Pout30_%s)" % u], (1e-3, 10))]
    if u != "woof":
        traces.append(([f"V(Vspkr_{u})/I(Yi_{u})"], (1, 100)))
    g.plt(out.with_suffix(".plt"), traces, (20, 20000))
    return out


# ---------------------------------------------------------------- system skeleton
class Asc:
    def __init__(self):
        self.l = []

    def w(self, x1, y1, x2, y2):
        self.l.append(f"WIRE {x1} {y1} {x2} {y2}")

    def flag(self, x, y, n):
        self.l.append(f"FLAG {x} {y} {n}")

    def t(self, x, y, txt, d=False):
        self.l.append(f"TEXT {x} {y} Left 2 {'!' if d else ';'}{txt}")

    def e(self, x, y, name, val, cin, cneg="0", oneg="0", hide=False):
        """E source with its + output at (x, y); returns that point. Control and - output by flags.
        hide=True keeps a long value (a Laplace string) off the sheet, as the course files do."""
        self.l += [f"SYMBOL e {x} {y - 16} R0", "WINDOW 0 24 104 Left 2", f"WINDOW 3 24 136 {'Invisible' if hide else 'Left'} 2",
                   f"SYMATTR InstName {name}", f"SYMATTR Value {val}"]
        self.flag(x, y + 80, oneg)
        self.w(x - 48, y + 16, x - 96, y + 16); self.flag(x - 96, y + 16, cin)
        self.w(x - 48, y + 64, x - 96, y + 64); self.flag(x - 96, y + 64, cneg)
        return x, y

    def yi(self, x, y, name):
        """0 V current sense, current flows left -> right; pins at x and x + 80."""
        self.l += [f"SYMBOL voltage {x - 16} {y} R270", "WINDOW 0 32 56 VTop 2", "WINDOW 3 -32 56 VBottom 2",
                   f"SYMATTR InstName {name}", "SYMATTR Value 0"]
        return x + 80

    def dump(self, p):
        p.write_text("Version 4\nSHEET 1 3200 1800\n" + "\n".join(self.l) + "\n")


def system():
    a = Asc()
    a.t(-400, -400, "System D: three-way skeleton after Figure 1 of the project guide. Everything reads ../data (export_systemD.m). "
                    "It runs as it is: biquad slots = gain 1, passive slots = plain wires.")
    a.t(-400, -368, "Digital: paste DigitalCrossover.m's LaplaceTXT_E1/E2 into the Value of E_LP1/E_LP2 (woofer) and E_HP1/E_HP2 (mid/tweeter). "
                    "For n = 2 leave the second slot at 1.")
    a.t(-400, -336, "Passive: replace the wire inside each dashed box with the filter. Values only from Appendix 1. "
                    "Sum: V(Psum) on axis, V(Psum30) at 30 deg; gains g_ and polarities p_ below.")
    a.l += ["SYMBOL voltage -400 -16 R0", "WINDOW 0 -56 40 Right 2", "WINDOW 3 -56 72 Right 2",
            "SYMATTR InstName V1", "SYMATTR Value 0", "SYMATTR Value2 AC 1"]
    a.flag(-400, 0, "Vin"); a.flag(-400, 80, "0")
    # digital branches
    for row, (tag, out, txt) in enumerate((("LP", "Vspkr_woof", "woofer: digital LPF (MiniDSP output 1)"),
                                           ("HP", "Vhp", "mid + tweeter: digital HPF (MiniDSP output 2)"))):
        y = row * 320
        a.t(-80, y - 96, txt)
        a.e(0, y, f"E_{tag}1", "1", "Vin")
        a.w(0, y, 112, y); a.flag(112, y, f"{tag.lower()}1")
        a.e(256, y, f"E_{tag}2", "1", f"{tag.lower()}1")
        a.w(256, y, 400, y); a.flag(400, y, out)
    a.t(560, -16, "woofer TF: V(Pout_woof)")
    # passive branches from Vhp
    for row, (u, kind) in enumerate((("mid", "LPF"), ("tw", "HPF"))):
        y = 640 + row * 352
        a.flag(0, y, "Vhp"); a.w(0, y, 448, y)
        a.l += [f"RECTANGLE Normal 64 {y - 112} 400 {y + 144} 2"]
        a.t(80, y - 96, f"passive {kind} ({UNITS[u]}): replace this wire")
        x = a.yi(528, y, f"Yi_{u}"); a.w(448, y, 528, y); a.w(x, y, x + 96, y); a.flag(x + 96, y, f"Vspkr_{u}")
        a.t(x + 160, y - 16, f"Zi + TF of the {UNITS[u]} hang on Vspkr_{u} (.inc below)")
    # sums
    for k, (sfx, lab) in enumerate((("", "on axis"), ("30", "30 deg"))):
        x = 1600 + k * 640
        a.t(x - 160, -96, f"sum, {lab}: series E sources")
        nodes = ["0", f"s{sfx}1", f"s{sfx}2", f"Psum{sfx}"]
        for j, u in enumerate(("woof", "mid", "tw")):
            y = 160 + j * 256
            a.e(x, y, f"E_S{sfx}{u}", f"{{g_{u}*p_{u}}}", f"Pout{sfx}_{u}", oneg=nodes[j])
            a.w(x, y, x + 112, y); a.flag(x + 112, y, nodes[j + 1])
    a.t(1440, 960, ".param g_woof=1 g_mid=1 g_tw=1   p_woof=1 p_mid=1 p_tw=1", d=True)
    a.t(1440, 1000, "g_woof = woofer/mid level difference (= MiniDSP output gain); p_ = +1 / -1 polarity of each unit")
    y = 1100
    for i, f in enumerate(["TF_woof", "TF30_woof", "Zi_mid", "TF_mid", "TF30_mid", "Zi_tw", "TF_tw", "TF30_tw"]):
        a.t(-400 + (i % 4) * 400, y + (i // 4) * 40, f".inc ../data/{f}.txt", d=True)
    a.t(-400, y + 120, ".ac dec 200 20 20000", d=True)
    p = HERE / "System_template.asc"
    a.dump(p)
    g.plt(p.with_suffix(".plt"), [(["V(Psum)", "V(Psum30)", "V(Pout_woof)", "V(Pout_mid)", "V(Pout_tw)"], (1e-3, 10))], (20, 20000))
    return p


# ---------------------------------------------------------------- verification
def run(asc):
    """Run LTspice on a copy in a space-free temp tree that keeps the ../data and ../../data paths."""
    env = dict(os.environ, WINEARCH="win64", WINEPREFIX=os.path.expanduser("~/.local/share/wineprefixes/ltspice"), WINEDEBUG="-all")
    exe = "/usr/share/ltspice/LTspice.exe"
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="ltproj_"))
    shutil.copytree(DATA, tmp / "p" / "data", ignore=shutil.ignore_patterns("csv"))
    rel = asc.relative_to(HERE.parent)
    work = tmp / "p" / rel; work.parent.mkdir(parents=True, exist_ok=True); shutil.copy(asc, work)
    wp = lambda q: subprocess.run(["winepath", "-w", str(q)], env=env, capture_output=True, text=True).stdout.strip()
    subprocess.run(["wine", exe, "-netlist", wp(work)], env=env, capture_output=True, timeout=120, cwd=work.parent)
    subprocess.run(["wine", exe, "-b", wp(work.with_suffix(".net"))], env=env, capture_output=True, timeout=300, cwd=work.parent)
    raw = work.with_suffix(".raw")
    if not raw.exists():
        log = work.with_suffix(".log")
        raise SystemExit(f"{asc.name} failed:\n" + (log_text(log) if log.exists() else "no log"))
    d = g.read_raw(raw); shutil.rmtree(tmp, ignore_errors=True)
    return {k: np.array(v) for k, v in d.items()}


def log_text(log):
    b = log.read_bytes()
    return b.decode("utf-16le", "ignore") if b[1:2] == b"\x00" else b.decode("utf-8", "ignore")


def csv(name):
    m = np.genfromtxt(DATA / "csv" / f"{name}.csv", delimiter=",", names=True)
    return m["f"], m["re"] + 1j * m["im"]


def compare(f_lt, y_lt, f_m, y_m, lo, hi):
    """Worst dB and degree error inside [lo, hi], at LTspice's frequencies. The measured table is
    interpolated the way LTspice reads it (dB and unwrapped phase, linear in f); comparing the
    other way round puts the error on every noisy notch between two table points."""
    k = (f_lt >= lo) & (f_lt <= hi)
    mag = np.interp(f_lt[k], f_m, 20 * np.log10(np.abs(y_m)))
    ph = np.interp(f_lt[k], f_m, np.unwrap(np.angle(y_m)))
    dm = np.max(np.abs(mag - 20 * np.log10(np.abs(y_lt[k]))))
    dp = np.angle(np.exp(1j * (ph - np.angle(y_lt[k]))))
    return dm, np.degrees(np.max(np.abs(dp)))


def verify(units, sysf):
    ok = True
    for u, asc in units.items():
        d = run(asc); f = d["frequency"].real
        checks = []
        for sfx, tag in (("", "on"), ("30", "off30")):
            fm, H = csv(f"TF_{tag}_{UNITS[u]}")
            H = H * np.exp(1j * 2 * np.pi * fm * D / C_PU)        # what Matlab2LTspice put in the file
            checks.append((f"p/V {tag:5s}", *compare(f, d[f"v(pout{sfx}_{u})"], fm, H, 50, 18000)))
        if u != "woof":
            fm, Z = csv(f"Z_{UNITS[u]}")
            checks.append(("Z_i      ", *compare(f, d[f"v(vspkr_{u})"] / d[f"i(yi_{u})"], fm, Z, 100 if u == "tw" else 20, 18000)))
        for lab, dm, dp in checks:
            good = dm < 0.2 and dp < 2; ok &= good
            print(f"  {'OK ' if good else 'BAD'} {asc.name:14s} {lab}: worst {dm:.3f} dB, {dp:.2f} deg")
    d = run(sysf); f = d["frequency"].real
    want = sum(d[f"v(pout_{u})"] for u in UNITS)
    dev = np.max(np.abs(d["v(psum)"] / want - 1)); good = dev < 1e-6; ok &= good
    print(f"  {'OK ' if good else 'BAD'} System_template: V(Psum) = sum of the three units to {dev:.1e}")
    print("ALL OK" if ok else "MISMATCH")
    return ok


if __name__ == "__main__":
    units = {u: unit(u) for u in UNITS}
    sysf = system()
    for p in list(units.values()) + [sysf]:
        print("wrote", p.relative_to(HERE))
    if "--verify" in sys.argv:
        sys.exit(0 if verify(units, sysf) else 1)
