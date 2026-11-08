#!/usr/bin/env python3
"""Quiz part 1, Q10: the complete System D crossover drawn exactly like the course examples
(Passive_Filters_And_Measurement_Data_in_LTspice.zip and Digital_Filters_to_MiniDSP_&_LTspice.zip).

    python3 gen_system_course.py            # write System_D_course.asc/.plt
    python3 gen_system_course.py --verify   # run LTspice at the Lab E frequencies, compare with xover.py
    python3 gen_system_course.py --preview  # draw the schematic to preview/*.png

One row per unit, each the course template moved down the sheet:
    V1 (Vin) -> E1, E2 (DigitalCrossover.m biquads) -> passive filter -> Yi -> Vspkr -> [Zin] [TF] -> Pout -> R 1k
  woofer:  MiniDSP output 1, LR4 low-pass, no passive filter, Zi not needed (";.inc", as in the course file)
  mid:     MiniDSP output 2, LR4 high-pass -> Vhp -> passive LP2
  tweeter: the same Vhp -> passive HP2 + L-pad
and the three Pouts summed by series E sources (gain = MiniDSP output gain x polarity), as the
Project Guide asks. Unlike System_D_design.asc there is NO Task 1 box stage: the woofer TF is the
Lab E anechoic measurement (vents plugged, valid above ~125 Hz), the low end is Task 1's job.
"""
import json, pathlib, sys
import numpy as np

HERE = pathlib.Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / "design"))
import gen_templates as T                    # noqa: E402
import xover as X                            # noqa: E402

NAME = "System_D_course"
S = 640                                      # course coordinates shifted right to make room for the filters
ROW = 512                                    # rows are 512 apart


class Sheet:
    def __init__(self):
        self.w, self.f, self.s, self.t, self.g = [], [], [], [], []

    def wire(self, *p):
        for a, b in zip(p[:-1], p[1:]):
            self.w.append(f"WIRE {a[0]} {a[1]} {b[0]} {b[1]}")

    def flag(self, x, y, n, io=False):
        self.f.append(f"FLAG {x} {y} {n}")
        if io:
            self.f.append(f"IOPIN {x} {y} Out")

    def gnd(self, x, y):
        self.flag(x, y, "0")

    def sym(self, kind, x, y, rot, name, value, extra=()):
        self.s += [f"SYMBOL {kind} {x} {y} {rot}", *extra, f"SYMATTR InstName {name}"]
        if value is not None:
            self.s.append(f"SYMATTR Value {value}")

    def text(self, x, y, s, d=False, align="Left"):
        self.t.append(f"TEXT {x} {y} {align} 2 {'!' if d else ';'}{s}")

    def rect(self, x1, y1, x2, y2):
        self.g.append(f"RECTANGLE Normal {x2} {y2} {x1} {y1} 2")

    def line(self, x1, y1, x2, y2):
        self.g.append(f"LINE Normal {x1} {y1} {x2} {y2} 2")

    def dump(self, path):
        lines = ["Version 4", "SHEET 1 3600 2400"] + self.w + self.f + self.s + self.t + self.g
        path.write_bytes(("\n".join(lines) + "\n").encode("latin1"))


def fmt(kind, v):
    return {"L": f"{v*1e3:g}m", "C": f"{v*1e6:g}u", "R": f"{v:g}"}[kind]


SYM = {"L": "ind", "C": "cap", "R": "res"}
H_WIN = ["WINDOW 0 0 56 VBottom 2", "WINDOW 3 32 56 VTop 2"]          # ind/res turned R90
C_WIN = ["WINDOW 0 0 32 VBottom 2", "WINDOW 3 32 32 VTop 2"]          # cap R90, as in the course file


def passive(sh, x, y, parts, tag):
    """Course-style ladder on the rail at y (ground rail y + 176) from x. Returns the end x."""
    for i, (pos, kind, v) in enumerate(parts):
        name = f"{kind}{i + 1}_{tag}"
        sl = ["SYMATTR SpiceLine Rser=0"] if kind == "L" else []
        if pos == "series":
            if kind == "C":                                          # pins (X-64, y) .. (X, y)
                sh.sym("cap", x + 64, y - 16, "R90", name, fmt(kind, v), C_WIN)
                x2 = x + 64
            else:                                                    # pins (X-96, y) .. (X-16, y)
                sh.sym(SYM[kind], x + 96, y - 16, "R90", name, fmt(kind, v), H_WIN)
                sh.s += sl
                x2 = x + 80
            sh.wire((x2, y), (x2 + 48, y)); x = x2 + 48
        else:
            xs = x + 64
            sh.wire((x, y), (xs, y))
            if kind == "C":                                          # pins (xs, y+48) .. (xs, y+112)
                sh.sym("cap", xs - 16, y + 48, "R0", name, fmt(kind, v))
                sh.wire((xs, y), (xs, y + 48)); sh.wire((xs, y + 112), (xs, y + 176))
            else:                                                    # pins (xs, y+48) .. (xs, y+128)
                sh.sym(SYM[kind], xs - 16, y + 32, "R0", name, fmt(kind, v))
                sh.s += sl
                sh.wire((xs, y), (xs, y + 48)); sh.wire((xs, y + 128), (xs, y + 176))
            x = xs + 64
            sh.wire((xs, y), (x, y))
    return x


def esrc(sh, x, y, name, value, hide=True):
    """Course E symbol at (x, y): out+ (x, y+16), out- (x, y+96), in+ (x-48, y+32), in- (x-48, y+80)."""
    win = ["WINDOW 3 24 96 Invisible 2"] if hide else ["WINDOW 3 24 104 Left 2"]
    sh.sym("e", x, y, "R0", name, value, win)


def digital(sh, dy, strs, tag, src):
    """The course digital block: (src) -> E1 -> E2 -> rail at y = dy + 80, out at (176, dy + 80)."""
    y, gy = dy + 80, dy + 256
    if src == "V1":
        sh.sym("voltage", -336, dy + 112, "R0", "V1", '""',
               ["WINDOW 123 24 120 Left 2", "WINDOW 39 0 0 Left 0"])
        sh.s.append("SYMATTR Value2 AC 1")
        sh.wire((-336, dy + 64), (-336, y), (-144, y)); sh.wire((-336, dy + 128), (-336, y))
        sh.wire((-336, dy + 208), (-336, gy), (-144, gy)); sh.flag(-336, dy + 64, "Vin", io=True)
    else:
        sh.flag(-240, y, "Vin"); sh.wire((-240, y), (-144, y)); sh.wire((-240, gy), (-144, gy))
    sh.wire((-144, y), (-144, dy + 144), (-112, dy + 144)); sh.wire((-112, dy + 192), (-144, dy + 192), (-144, gy))
    esrc(sh, -64, dy + 112, f"E1_{tag}", strs[0])
    sh.wire((-64, dy + 128), (-64, y), (96, y), (96, dy + 144), (128, dy + 144))
    sh.wire((-64, dy + 208), (-64, gy), (96, gy), (96, dy + 192), (128, dy + 192))
    esrc(sh, 176, dy + 112, f"E2_{tag}", strs[1])
    sh.wire((176, dy + 128), (176, y)); sh.wire((176, dy + 208), (176, gy))
    sh.gnd(-144, gy + 16); sh.wire((-144, gy), (-144, gy + 16)); sh.wire((-144, gy), (-64, gy))
    sh.rect(-192, dy + 32, 256, dy + 288)


def unit_end(sh, dy, x, tag, zi=True):
    """Course right half: rail from x to Yi -> Vspkr -> generators -> Pout -> R 1k."""
    y, gy = dy + 80, dy + 256
    sh.wire((x, y), (352 + S + 16, y))
    sh.sym("voltage", 352 + S, y, "R270", f"Yi_{tag}", '""',
           ["WINDOW 0 32 56 VTop 2", "WINDOW 3 -32 56 VBottom 2", "WINDOW 123 -34 56 VBottom 2", "WINDOW 39 0 0 Left 0"])
    sh.s.append("SYMATTR Value2 AC 0")
    xv, xp, xr = 512 + S, 736 + S, 912 + S
    sh.wire((448 + S, y), (xv, y)); sh.flag(xv, dy + 64, f"Vspkr_{tag}", io=True); sh.wire((xv, dy + 64), (xv, y))
    sh.flag(xp, dy + 64, f"Pout_{tag}", io=True); sh.wire((xp, dy + 64), (xp, y), (xr, y), (xr, dy + 128))
    sh.sym("res", 896 + S, dy + 112, "R0", f"R_{tag}", "1k", ["WINDOW 3 36 76 Invisible 2"])
    sh.wire((xr, dy + 208), (xr, gy), (xp, gy), (xp, gy + 16)); sh.gnd(xp, gy + 16)
    sh.wire((xv, gy), (x, gy)); sh.wire((xv, gy), (xv, gy + 16)); sh.gnd(xv, gy + 16)
    for x0 in (xv, xp):                                                # dashed generators, as in the course file
        sh.line(x0, y, x0, dy + 144); sh.line(x0, dy + 208, x0, gy)
    sh.rect(432 + S, dy + 144, 592 + S, dy + 208); sh.rect(656 + S, dy + 144, 816 + S, dy + 208)
    sh.text(520 + S, dy + 168, "Zin\\ngenerator", align="Center"); sh.text(736 + S, dy + 168, "Transfer Func.\\ngenerator", align="Center")
    if zi:
        sh.text(432 + S, dy + 304, f".inc ../data/Zi_{tag}.txt", d=True)
    else:
        sh.text(432 + S, dy + 304, f".inc Zi_{tag}.txt   (not needed for the woofer)")
    sh.text(432 + S, dy + 336, f".inc ../data/TF_{tag}.txt", d=True)
    sh.text(432 + S, dy + 368, f".inc ../data/TF30_{tag}.txt", d=True)


def summer(sh, x, y0, sfx, lab):
    """Series E sources (Project Guide): V(Psum) = sum of g*p*V(Pout) of the three units."""
    nodes = ["0"] + [f"s{sfx}{k}" for k in (1, 2)] + [f"Psum{sfx}"]
    sh.text(x - 160, y0 - 64, f"sum, {lab}")
    for j, u in enumerate(("woof", "mid", "tw")):
        y = y0 + (2 - j) * 160                                        # woofer at the bottom
        esrc(sh, x, y, f"E_S{sfx}{u}", f"{{g_{u}*p_{u}}}", hide=False)
        sh.wire((x - 48, y + 32), (x - 128, y + 32)); sh.flag(x - 128, y + 32, f"Pout{sfx}_{u}"); sh.flag(x - 48, y + 80, "0")
        if j == 0:
            sh.wire((x, y + 96), (x, y + 112)); sh.gnd(x, y + 112)
        else:
            sh.wire((x, y + 96), (x, y + 176))                        # out- to the out+ below
    sh.wire((x, y0 + 16), (x, y0 - 16)); sh.flag(x, y0 - 16, nodes[-1], io=True)


def build(des):
    dg = des["digital"]
    LP = X.ltspice_text(dg["fc"], "LPF", dg["align"]); HP = X.ltspice_text(dg["fc"], "HPF", dg["align"])
    LP += ["1"] * (2 - len(LP)); HP += ["1"] * (2 - len(HP))
    sh = Sheet()
    sh.text(-336, -160, "System D, Task 2: digital crossover (MiniDSP) + passive crossover, drawn as the course examples. "
                        "Zi and TF are the Lab D / Lab E measurements, included from text files (Matlab2LTspice format, same distance d = -1.15 m for all TFs).")
    sh.text(-336, -112, "The controlled sources come from the .inc files; the dashed boxes only show where they sit. "
                        "E1/E2 = DigitalCrossover.m biquads (n = 2, used twice = LR4), Value hidden: Ctrl+right-click to read it.")
    rows = (("woof", "woofer: MiniDSP output 1, LR4 low-pass 325 Hz, -4.5 dB -> amplifier ch. 1 -> woofer (no passive filter)"),
            ("mid", "midrange: MiniDSP output 2, LR4 high-pass 325 Hz -> amplifier ch. 2 -> Vhp -> passive LP2"),
            ("tw", "tweeter: same Vhp (amplifier ch. 2) -> passive HP2 + L-pad"))
    for k, (u, lab) in enumerate(rows):
        dy = k * ROW
        sh.text(-336, dy - 16, lab)
        if u == "woof":
            digital(sh, dy, LP, "woof", "V1"); x = 176
        elif u == "mid":
            digital(sh, dy, HP, "hp", "Vin")
            sh.wire((176, dy + 80), (272, dy + 80)); sh.flag(272, dy + 80, "Vhp")
            sh.wire((176, dy + 256), (272, dy + 256)); x = 272
        else:
            sh.flag(272, dy + 80, "Vhp"); x = 272
        if u != "woof":
            b = des[u]
            parts = X.passive_parts(b["topo"], b["vals"], pad=b.get("pad"))
            sh.wire((x, dy + 80), (x + 64, dy + 80)); x0 = x; x += 64
            x = passive(sh, x, dy + 80, parts, u)
            sh.wire((x0, dy + 256), (x, dy + 256))
            sh.rect(x0 - 16, dy + 32, max(x, 768) + 32, dy + 288)
            sh.text(x0, dy + 320, f"passive {'LPF' if u == 'mid' else 'HPF + L-pad'}")
        unit_end(sh, dy, x, u, zi=(u != "woof"))
    gw = 10 ** (dg["g_woof_dB"] / 20)
    xs = 1900
    summer(sh, xs, 80, "", "on axis")
    summer(sh, xs + 480, 80, "30", "30 deg")
    sh.text(xs - 160, 640, f".param g_woof={gw:.6g} g_mid=1 g_tw=1  p_woof={des['pol']['woof']} p_mid={des['pol']['mid']} p_tw={des['pol']['tw']}", d=True)
    sh.text(xs - 160, 680, f"g_woof = {dg['g_woof_dB']:+.1f} dB = MiniDSP output 1 gain;  p_ = polarity (+1 / -1)")
    sh.text(xs - 160, 720, "V(Psum) = the whole box on axis, V(Psum30) = 30 deg, as the mic at 2.44 m sees it, for 1 V in")
    sh.text(-336, 3 * ROW + 32, ".ac dec 1000 20 20000", d=True)
    p = HERE / f"{NAME}.asc"
    sh.dump(p)
    T.g.plt(p.with_suffix(".plt"), [(["V(Psum)", "V(Psum30)"], (0.05, 5)),
                                    (["V(Pout_woof)", "V(Pout_mid)", "V(Pout_tw)", "V(Psum)"], (1e-3, 5))], (20, 20000))
    return p


def verify(p, des):
    d = X.Data()
    txt = p.read_bytes().decode("latin1")
    q = p.with_name(NAME + "_verify.asc")
    q.write_bytes(txt.replace("!.ac dec 1000 20 20000", "!.ac list " + " ".join(f"{f:g}" for f in d.f)).encode("latin1"))
    r = T.run(q); q.unlink()
    ok = True
    for ang, sfx in (("on", ""), ("off30", "30")):
        out, _ = X.evaluate(d, des, ang)
        k = (d.f >= 100) & (d.f <= 18000)
        e = np.abs(20 * np.log10(np.abs(r[f"v(psum{sfx})"][k]) / np.abs(out["sum"][k])))
        good = np.median(e) < 0.05 and np.percentile(e, 95) < 0.3
        ok &= good
        print(f"  {'OK ' if good else 'BAD'} V(Psum{sfx}) vs xover.py 100 Hz-18 kHz: median {np.median(e):.3f} dB, 95 % {np.percentile(e, 95):.3f}, worst {e.max():.2f} dB")
    print("ALL OK" if ok else "MISMATCH")
    return ok


if __name__ == "__main__":
    des = json.loads((HERE.parent / "design" / "design.json").read_text())
    p = build(des)
    print("wrote", p.name)
    if "--preview" in sys.argv:
        import preview_asc as pv
        pv.HERE = HERE
        pv.main(str(p))
    if "--verify" in sys.argv:
        sys.exit(0 if verify(p, des) else 1)
