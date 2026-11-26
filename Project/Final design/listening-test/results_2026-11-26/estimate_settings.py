"""Estimated on-axis response of System D for every setting played on 26 Nov 2026 (test 2).

Copied from ../results_2026-11-18/estimate_settings.py; only the list of settings and the Part C figure
changed. The woofer level during Part C was not recorded on 26 Nov: PARTC_WOOFER assumes the operator
sheet was followed (Out 1 back to -5.8 dB after Part B; this session's Part B also ended on D).

    python3 estimate_settings.py

Built from the 12-Nov anechoic runs the same way as lab-day/analysis/results_1112.m:
woofer channel + mid/tweeter channel of ONE run (phase-coherent), with the doubled Out 2 high-pass
divided out of the mid/tweeter channel. S_3 = Rp 8.2 ohm, S_4 = Rp 3.3 ohm; both had Out 1 at -5.8 dB,
so another woofer gain is the woofer channel times 10^((g + 5.8)/20). Only Rp changed between S_3 and
S_4, so S_4 is level-matched to S_3 on the woofer channel (150-400 Hz); its log says 2.26 m, but the raw
woofer levels already agree, so no 1/r correction is applied. Writes fig_est_*.png and est_numbers.txt here.
Estimates, not measurements: nobody measured these settings with the corrected MiniDSP.
"""
from pathlib import Path

import numpy as np
import scipy.io as sio
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
LD = HERE.parents[1] / 'lab-day' / 'data'
fn = sio.loadmat(LD / '2026-11-10' / 'S.mat', squeeze_me=True)['fn'].astype(float)


def run(name):
    m = sio.loadmat(LD / '2026-11-12' / f'{name}.mat', squeeze_me=True)
    return [np.interp(fn, m['fn'], m['H'][:, k].real) + 1j * np.interp(fn, m['fn'], m['H'][:, k].imag)
            for k in (0, 1)]


# one MiniDSP high-pass biquad (BW2 section), as in results_1112.m; the extra LR4 = two of them
c = [0.985071534815898, -1.970143069631796, 0.985071534815898, 1.969920198141118, -0.970365941122475]
z1 = np.exp(-1j * 2 * np.pi * fn / 96000)
BQ = (c[0] + c[1] * z1 + c[2] * z1 ** 2) / (1 - c[3] * z1 - c[4] * z1 ** 2)
BQ2 = BQ ** 2
BQ2[fn < 150] = 1

w3, t3 = run('S_3')
w4, t4 = run('S_4')
_b = (fn >= 150) & (fn <= 400)
g4 = 10 ** (-np.median(20 * np.log10(np.abs(w4[_b]) / np.abs(w3[_b]))) / 20)   # level-match on the woofer
w4, t4 = w4 * g4, t4 * g4
t3, t4 = t3 / BQ2, t4 / BQ2
CH = {'R8': (w3, t3), 'R3': (w4, t4)}


def smooth(x, frac=6):
    lf = np.log2(fn)
    return np.array([np.nanmean(x[np.abs(lf - v) <= 1 / (2 * frac)]) for v in lf])


def response(woofer_db, rp):
    w, t = CH[rp]
    return smooth(20 * np.log10(np.abs(w * 10 ** ((woofer_db + 5.8) / 20) + t)))


band = lambda lo, hi: (fn >= lo) & (fn <= hi)
design = response(-5.8, 'R8')
REF = np.median(design[band(150, 15000)])
PARTC_WOOFER = -5.8   # assumed, see the docstring

SETTINGS = [  # label, woofer gain, Rp, where it was played
    ('Design: Out 1 −5.8 dB, Rp 8.2 Ω', -5.8, 'R8', 'Part A, Part B sample D, Part C Y (assumed)'),
    ('L: Out 1 −7.8 dB, Rp 8.2 Ω', -7.8, 'R8', 'Part B sample L'),
    ('H: Out 1 −3.8 dB, Rp 8.2 Ω', -3.8, 'R8', 'Part B sample H'),
    ('Out 1 −5.8 dB, Rp 3.3 Ω', PARTC_WOOFER, 'R3', 'Part C sample X (woofer assumed)'),
]
curves = {lab: response(g, rp) - REF for lab, g, rp, _ in SETTINGS}

# numbers: band levels against the 500 Hz-2 kHz midrange of the same curve
lines = ['Estimated on-axis response per setting (1/6 oct, 0 dB = median of the design 150 Hz-15 kHz)',
         'bands are relative to the same curve\'s 500 Hz-2 kHz median', '',
         f'{"setting":34} {"played in":40} {"150-300":>8} {"300-500":>8} {"2-4k":>7} {"4-8k":>7} {"8-15k":>7} {"spread 150-15k":>15}']
for lab, g, rp, where in SETTINGS:
    y = curves[lab]
    mid = np.median(y[band(500, 2000)])
    b = [np.median(y[band(lo, hi)]) - mid for lo, hi in ((150, 300), (300, 500), (2000, 4000), (4000, 8000), (8000, 15000))]
    k = band(150, 15000)
    lines.append(f'{lab:34} {where:40} ' + ' '.join(f'{v:+8.1f}' for v in b) +
                 f' {np.ptp(y[k]):8.1f} dB / {np.std(y[k]):.2f} rms')
lines += ['', f'S_4 level-matched to S_3 on the woofer (150-400 Hz): {20 * np.log10(g4):+.2f} dB applied',
          f'tweeter step Rp 8.2 vs 3.3 after matching, 5-15 kHz: '
          f'{np.median(curves["Design: Out 1 −5.8 dB, Rp 8.2 Ω"][band(5000, 15000)] - curves["Out 1 −5.8 dB, Rp 3.3 Ω"][band(5000, 15000)]):+.1f} dB',
          'below about 120 Hz the anechoic chamber is not valid; the vent was open from S_2 on']
(HERE / 'est_numbers.txt').write_text('\n'.join(lines) + '\n', encoding='utf-8')
print('\n'.join(lines))

plt.rcParams.update({'font.size': 10, 'axes.grid': True, 'grid.alpha': 0.3, 'axes.spines.top': False,
                     'axes.spines.right': False, 'savefig.dpi': 200, 'savefig.bbox': 'tight'})


def axes_setup(ax, title):
    ax.set_xscale('log'); ax.set_xlim(50, 20000); ax.set_ylim(-16, 12)
    ax.axvspan(50, 120, color='0.9', zorder=0)
    ax.text(57, -15, 'chamber not\nvalid here', fontsize=7, color='0.4', va='bottom')
    ax.fill_between([150, 15000], -2, 2, color='#e3f1e3', zorder=0)
    ax.set_xticks([100, 200, 500, 1000, 2000, 5000, 10000, 20000], ['100', '200', '500', '1k', '2k', '5k', '10k', '20k'])
    ax.set_xlabel('frequency [Hz]'); ax.set_ylabel('dB re design (1/6 oct)'); ax.set_title(title, fontsize=10)


# Figure 1: the woofer levels (Part B)
fig, ax = plt.subplots(figsize=(7.6, 3.8))
for lab, col, lw in [('L: Out 1 −7.8 dB, Rp 8.2 Ω', '#2a6fdb', 1.3), ('Design: Out 1 −5.8 dB, Rp 8.2 Ω', 'k', 2.2),
                     ('H: Out 1 −3.8 dB, Rp 8.2 Ω', '#d9822b', 1.3)]:
    ax.semilogx(fn, curves[lab], color=col, lw=lw, label=lab)
axes_setup(ax, 'Woofer level: Part B samples L / D / H (all Rp 8.2 Ω)')
ax.legend(fontsize=8, loc='lower center')
fig.savefig(HERE / 'fig_est_woofer.png'); plt.close(fig)

# Figure 2: Part C (woofer assumed at -5.8 dB): X = Rp 3.3, Y = Rp 8.2 (= the design)
fig, ax = plt.subplots(figsize=(7.6, 3.8))
ax.semilogx(fn, curves['Design: Out 1 −5.8 dB, Rp 8.2 Ω'], color='#d9822b', lw=1.6, label='Part C sample Y = design: Out 1 −5.8 dB, Rp 8.2 Ω')
ax.semilogx(fn, curves['Out 1 −5.8 dB, Rp 3.3 Ω'], color='#2e9e5b', lw=1.8, label='Part C sample X: Out 1 −5.8 dB, Rp 3.3 Ω (preferred 3 of 3)')
axes_setup(ax, 'Part C, test 2 (woofer assumed at the design −5.8 dB): Rp 3.3 vs 8.2 Ω')
ax.legend(fontsize=8, loc='lower center')
fig.savefig(HERE / 'fig_est_partC.png'); plt.close(fig)

print('figures written')
