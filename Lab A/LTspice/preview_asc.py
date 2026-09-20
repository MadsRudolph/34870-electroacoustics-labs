#!/usr/bin/env python3
"""Render an LTspice .asc to a PNG and lint it for unreadable spots (label on label,
label on a symbol, wire through a label). LTspice cannot export a picture headless,
so this draws the schematic itself from the .asy symbol geometry.

    python3 preview_asc.py Part1_DualDiaphragm.asc [more.asc ...]   # -> preview/<name>.png + lint report
"""
import glob, math, os, pathlib, sys
from PIL import Image, ImageDraw, ImageFont

HERE = pathlib.Path(__file__).resolve().parent
SYMDIR = next(iter(glob.glob(os.path.expanduser(
    "~/.local/share/wineprefixes/ltspice/drive_c/users/*/AppData/Local/LTspice/lib/sym"))), None)
FONT = next((f for f in ("/usr/share/fonts/liberation/LiberationSans-Bold.ttf",
                         "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
                         "/usr/share/fonts/noto/NotoSans-Bold.ttf") if os.path.exists(f)), None)
SIZES = {0: 0.625, 1: 1.0, 2: 1.5, 3: 2.0, 4: 2.5, 5: 3.5, 6: 5.0, 7: 7.0}
PX = 17                       # text height in schematic units per unit of LTspice size factor
ROT = {"R0": lambda x, y: (x, y), "R90": lambda x, y: (-y, x), "R180": lambda x, y: (-x, -y), "R270": lambda x, y: (y, -x)}


def font(size):
    return ImageFont.truetype(FONT, max(6, int(SIZES[size] * PX))) if FONT else ImageFont.load_default()


def load_sym(kind):
    geo, wins = [], {}
    for ln in open(os.path.join(SYMDIR, kind + ".asy"), errors="ignore").read().splitlines():
        t = ln.split()
        if not t:
            continue
        if t[0] in ("LINE", "RECT", "CIRCLE", "ARC"):
            geo.append((t[0], [int(v) for v in t[2:]]))
        elif t[0] == "WINDOW":
            wins[int(t[1])] = (int(t[2]), int(t[3]), t[4], int(t[5]))
    return geo, wins


def parse(path):
    wires, flags, syms, texts = [], [], [], []
    cur = None
    for ln in open(path).read().splitlines():
        t = ln.split()
        if not t:
            continue
        if t[0] == "WIRE":
            wires.append(tuple(int(v) for v in t[1:5]))
        elif t[0] == "FLAG":
            flags.append((int(t[1]), int(t[2]), t[3]))
        elif t[0] == "SYMBOL":
            cur = {"kind": t[1], "x": int(t[2]), "y": int(t[3]), "rot": t[4], "win": {}, "attr": {}}
            syms.append(cur)
        elif t[0] == "WINDOW" and cur:
            cur["win"][int(t[1])] = (int(t[2]), int(t[3]), t[4], int(t[5]))
        elif t[0] == "SYMATTR" and cur:
            cur["attr"][t[1]] = ln.split(None, 2)[2]
        elif t[0] == "TEXT":
            body = ln.split(None, 5)[5]
            texts.append((int(t[1]), int(t[2]), t[3], int(t[4]), body[1:].split("\\n"), body[0] == "!"))
    return wires, flags, syms, texts


def text_box(x, y, just, size, s, rot="R0"):
    """bounding box of a label. V-justified text is vertical in the symbol frame; R90/R270 turn it."""
    vert = just.startswith("V")
    j = just[1:] if vert else just
    if rot in ("R90", "R270"):
        vert = not vert
    if rot in ("R180", "R270"):
        j = {"Left": "Right", "Right": "Left", "Top": "Bottom", "Bottom": "Top"}.get(j, j)
    f = font(size)
    l, t, r, b = f.getbbox(s)
    w, h = r - l, int(SIZES[size] * PX)
    if vert:                      # not used by the generator; keep a sane box anyway
        w, h = h, w
    if j == "Left":
        return (x, y - h / 2, x + w, y + h / 2)
    if j == "Right":
        return (x - w, y - h / 2, x, y + h / 2)
    if j == "Top":
        return (x - w / 2, y, x + w / 2, y + h)
    if j == "Bottom":
        return (x - w / 2, y - h, x + w / 2, y)
    return (x - w / 2, y - h / 2, x + w / 2, y + h / 2)


def overlap(a, b, m=2):
    return a[0] < b[2] - m and b[0] < a[2] - m and a[1] < b[3] - m and b[1] < a[3] - m


def main(path):
    wires, flags, syms, texts = parse(path)
    labels, bodies, shapes = [], [], []          # (box, text, size, what)
    for s in syms:
        geo, wins = load_sym(s["kind"])
        r = ROT[s["rot"]]
        P = lambda x, y: (s["x"] + r(x, y)[0], s["y"] + r(x, y)[1])
        xs, ys = [], []
        for kind, v in geo:
            pts = [P(v[i], v[i + 1]) for i in range(0, len(v), 2)]
            shapes.append((kind, pts))
            for p in pts[:2]:
                xs.append(p[0]); ys.append(p[1])
        bodies.append(((min(xs), min(ys), max(xs), max(ys)), s["attr"].get("InstName", "?")))
        wins = {**wins, **s["win"]}
        for idx, key in ((0, "InstName"), (3, "Value"), (123, "Value2"), (39, "SpiceLine")):
            if idx in wins and key in s["attr"] and (idx in (0, 3) or idx in s["win"]):
                wx, wy, just, size = wins[idx]
                labels.append((text_box(*P(wx, wy), just, size, s["attr"][key], s["rot"]), s["attr"][key], size, "label:" + s["attr"].get("InstName", "")))
    for x, y, name in flags:
        if name != "0":
            labels.append((text_box(x, y - 2, "Bottom", 2, name), name, 2, "node"))
    for x, y, just, size, lines, _ in texts:
        h = SIZES[size] * PX * 1.25
        for i, ln in enumerate(lines):
            labels.append((text_box(x, y + i * h, just, size, ln), ln, size, "text"))

    # ---- lint
    issues = []
    for i, a in enumerate(labels):
        for b in labels[i + 1:]:
            if overlap(a[0], b[0]):
                issues.append(f"label on label:  '{a[1][:28]}'  x  '{b[1][:28]}'")
        for box, name in bodies:
            if overlap(a[0], box, 4) and a[3] != "text" and a[3] != "label:" + name:
                issues.append(f"label on symbol: '{a[1][:28]}'  x  {name}")
        for w in wires:
            wb = (min(w[0], w[2]) - 1, min(w[1], w[3]) - 1, max(w[0], w[2]) + 1, max(w[1], w[3]) + 1)
            if overlap(a[0], wb, 3):
                issues.append(f"wire through:    '{a[1][:28]}'")
                break

    # ---- draw
    allx = [v for b in labels for v in (b[0][0], b[0][2])] + [v for w in wires for v in (w[0], w[2])]
    ally = [v for b in labels for v in (b[0][1], b[0][3])] + [v for w in wires for v in (w[1], w[3])] + [y + 40 for _, y, n in flags]
    x0, y0, x1, y1 = min(allx) - 40, min(ally) - 40, max(allx) + 40, max(ally) + 40
    img = Image.new("RGB", (int(x1 - x0), int(y1 - y0)), "#c0c0c0")
    d = ImageDraw.Draw(img)
    T = lambda p: (p[0] - x0, p[1] - y0)
    BLUE = "#0000c8"
    for w in wires:
        d.line([T(w[:2]), T(w[2:])], fill=BLUE, width=2)
    for kind, pts in shapes:
        if kind == "LINE":
            d.line([T(pts[0]), T(pts[1])], fill=BLUE, width=2)
        else:
            a, b = T(pts[0]), T(pts[1])
            box = [min(a[0], b[0]), min(a[1], b[1]), max(a[0], b[0]), max(a[1], b[1])]
            if kind == "RECT":
                d.rectangle(box, outline=BLUE, width=2)
            elif kind == "CIRCLE":
                d.ellipse(box, outline=BLUE, width=2)
            else:                                   # ARC: start/end points, counter-clockwise on screen
                cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
                s_, e_ = T(pts[2]), T(pts[3])
                a0 = math.degrees(math.atan2(s_[1] - cy, s_[0] - cx)); a1 = math.degrees(math.atan2(e_[1] - cy, e_[0] - cx))
                d.arc(box, a1, a0, fill=BLUE, width=2)
    for x, y, name in flags:
        if name == "0":
            px, py = T((x, y))
            d.polygon([(px - 16, py), (px + 16, py), (px, py + 16)], outline=BLUE)
    for box, s, size, what in labels:
        d.text(T((box[0], box[1])), s, fill=BLUE if what == "text" and not s.startswith(".") else "black", font=font(size))
    out = HERE / "preview"; out.mkdir(exist_ok=True)
    png = out / (pathlib.Path(path).stem + ".png")
    img.save(png)
    print(f"{pathlib.Path(path).name}: {len(issues)} issue(s) -> {png.relative_to(HERE)}")
    for i in issues:
        print("   ", i)
    return len(issues)


if __name__ == "__main__":
    files = sys.argv[1:] or sorted(str(p) for p in HERE.glob("*.asc"))
    sys.exit(1 if sum(main(f) for f in files) else 0)
