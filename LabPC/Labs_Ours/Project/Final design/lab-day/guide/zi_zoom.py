"""Board-input impedance on a log |Z| axis, for the lab-day guide (reads ../model/expected_zi.csv)."""
import csv
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

here = Path(__file__).resolve().parent
rows = list(csv.reader(open(here.parent / "model" / "expected_zi.csv")))
h, d = rows[0], np.array(rows[1:], float)
f = d[:, 0]
Z = lambda c: d[:, h.index(c + "_re")] + 1j * d[:, h.index(c + "_im")]

fig, ax = plt.subplots(2, 1, figsize=(8, 5.6), sharex=True)
for c, col, lab in [("Zboth", "k", "Z1 board (both drivers)"),
                    ("Zmid", "tab:orange", "Z2 board_mid (tweeter lead off)"),
                    ("Ztw", "tab:green", "Z3 board_tw (midrange lead off)")]:
    ax[0].loglog(f, abs(Z(c)), color=col, lw=1.6, label=lab)
    ax[1].semilogx(f, np.angle(Z(c), deg=True), color=col, lw=1.4)
ax[0].loglog(f, abs(Z("Zboth_dcr06")), "k:", lw=1.2, label="Z1 with coils 0.6 ohm/mH")
i = np.argmin(abs(Z("Zboth")))
ax[0].plot(f[i], abs(Z("Zboth"))[i], "ko", ms=5)
ax[0].annotate(f"min {abs(Z('Zboth'))[i]:.1f} ohm at {f[i]/1e3:.1f} kHz", (f[i], abs(Z("Zboth"))[i]),
               xytext=(-150, -28), textcoords="offset points", fontsize=9,
               arrowprops=dict(arrowstyle="->", lw=0.8))
j = np.argmin(abs(Z("Zmid")))
ax[0].plot(f[j], abs(Z("Zmid"))[j], "o", color="tab:orange", ms=5)
ax[0].annotate(f"min {abs(Z('Zmid'))[j]:.1f} ohm at {f[j]:.0f} Hz", (f[j], abs(Z("Zmid"))[j]),
               xytext=(-20, -30), textcoords="offset points", fontsize=9,
               arrowprops=dict(arrowstyle="->", lw=0.8))
ax[0].set_ylim(3, 700)
ax[0].set_yticks([3, 5, 10, 20, 50, 100, 200, 500]); ax[0].yaxis.set_minor_formatter(matplotlib.ticker.NullFormatter())
ax[0].get_yaxis().set_major_formatter(matplotlib.ticker.ScalarFormatter())
ax[0].set_ylabel("|Z| (ohm)")
ax[0].legend(fontsize=8, loc="upper center", ncol=2)
ax[0].set_title("Expected impedance at the board input (model, Lab D driver data)")
ax[1].set_ylabel("phase (deg)")
ax[1].set_xlabel("frequency (Hz)")
ax[1].set_ylim(-95, 95)
ax[1].set_yticks([-90, -45, 0, 45, 90])
for a in ax:
    a.grid(True, which="both", alpha=0.3)
    a.set_xlim(f[0], f[-1])
fig.tight_layout()
fig.savefig(here / "expected_zi_log.png", dpi=150)
print("wrote expected_zi_log.png")
