"""Listening test 18 Nov 2026: numbers and figures from the phone-form export.

    python3 analyze_listening.py            (reads listening_results_2026-11-18.csv next to this file)

Writes numbers.txt and fig_*.png into this folder. The CSV is the /results.csv export of
https://listening.madsrudolph.dev with the blind conditions already filled in.
"""
import csv
import statistics as st
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
CSV = HERE / 'listening_results_2026-11-18.csv'
R = list(csv.DictReader(open(CSV, encoding='utf-8')))
LISTENERS = sorted({r['listener'] for r in R}, key=lambda k: 'LMR'.index(k[-1]))
TRACKS = ['track1', 'track2', 'track3', 'track4']
TRACK_NAMES = ['Alison Krauss', 'Stevie Wonder', 'The Prodigy', 'Pink Floyd']
B_GAIN = {'L': -7.8, 'D': -5.8, 'H': -3.8}
COLORS = {'L': '#2a6fdb', 'M': '#d9822b', 'R': '#2e9e5b'}
SEAT = {'L': 'left', 'M': 'middle', 'R': 'right'}

plt.rcParams.update({'font.size': 10, 'axes.grid': True, 'grid.alpha': 0.3, 'axes.spines.top': False,
                     'axes.spines.right': False, 'savefig.dpi': 200, 'savefig.bbox': 'tight'})


def vals(**kw):
    return [float(r['score']) for r in R if all(r[k] == v for k, v in kw.items())]


def ms(v):
    return (st.mean(v), st.stdev(v) if len(v) > 1 else 0.0, len(v)) if v else (float('nan'), 0.0, 0)


def fmt(v):
    m, s, n = ms(v)
    return f'{m:5.2f} (sd {s:.2f}, n={n})'


out = []
p = out.append
p('Listening test 18 Nov 2026, IEC listening room, System D')
p(f'source: {CSV.name}, {len(R)} rows')
p('')
p('Listeners')
for k in LISTENERS:
    r = next(x for x in R if x['listener'] == k)
    p(f"  {k}: session {r['session']}, seat {SEAT[r['seat']]}, group member {r['group_member']}, "
      f"experience {r['experience']}, hearing issue {r['hearing']}")

p('')
p('Part A, the loudspeaker as designed (Out 1 -5.8 dB, Rp 8.2 ohm); mean per track, then all tracks')
A_ATTR = ['bass_amount', 'bass_quality', 'natural', 'treble_amount', 'treble_smooth', 'clarity', 'overall']
for a in A_ATTR:
    per = '  '.join(f'{ms(vals(part="A", item=t, attribute=a))[0]:5.2f}' for t in TRACKS)
    p(f'  {a:14} {per}   all {fmt(vals(part="A", attribute=a))}')
p('  by seat, overall:        ' + '  '.join(f'{SEAT[k[-1]]} {ms(vals(part="A", listener=k, attribute="overall"))[0]:.2f}'
                                         for k in LISTENERS))
p('  by seat, treble amount:  ' + '  '.join(f'{SEAT[k[-1]]} {ms(vals(part="A", listener=k, attribute="treble_amount"))[0]:+.2f}'
                                         for k in LISTENERS))

p('')
p('Part B, woofer level (Out 1: L -7.8, D -5.8, H -3.8 dB); D was played twice')
for c in 'LDH':
    best = sum(1 for r in R if r['part'] == 'B' and r['attribute'] == 'best_sample' and r['condition'] == c)
    p(f'  {c} ({B_GAIN[c]:+.1f} dB): overall {fmt(vals(part="B", condition=c, attribute="overall"))}, '
      f'bass amount {fmt(vals(part="B", condition=c, attribute="bass_amount"))}, chosen best {best}')
p('  repeat of D, overall (first, second):')
for k in LISTENERS:
    d = [float(r['score']) for r in sorted(R, key=lambda x: x['item'])
         if r['listener'] == k and r['part'] == 'B' and r['condition'] == 'D' and r['attribute'] == 'overall']
    p(f'    {k}: {d[0]:.0f}, {d[1]:.0f}  (difference {abs(d[1] - d[0]):.0f})')

p('')
p('Part C, tweeter L-pad (R8 = Rp 8.2 ohm, R3 = Rp 3.3 ohm, i.e. tweeter 2.9 dB lower)')
p('  NOTE: the woofer was left at -3.8 dB (H) from Part B for both samples, not the design -5.8 dB')
for c in ['R8', 'R3']:
    pref = sum(1 for r in R if r['part'] == 'C' and r['attribute'] == 'preferred' and r['condition'] == c)
    p(f'  {c}: overall {fmt(vals(part="C", condition=c, attribute="overall"))}, '
      f'treble amount {fmt(vals(part="C", condition=c, attribute="treble_amount"))}, '
      f'smoothness {fmt(vals(part="C", condition=c, attribute="treble_smooth"))}, preferred {pref}')
p(f'  no difference: {sum(1 for r in R if r["part"] == "C" and r["attribute"] == "preferred" and r["condition"] == "none")}')

p('')
p('Comments (verbatim)')
for r in R:
    if r['attribute'] == 'comment' and r['score'].strip():
        p(f"  {r['listener']} {r['part']} {r['item']} {r['condition']}: " + ' '.join(r['score'].split()))
(HERE / 'numbers.txt').write_text('\n'.join(out) + '\n', encoding='utf-8')
print('\n'.join(out))

# ---------------- figures ----------------
# 1. Part A overall per track, with each listener
fig, ax = plt.subplots(figsize=(6.4, 3.2))
for j, t in enumerate(TRACKS):
    m = ms(vals(part='A', item=t, attribute='overall'))[0]
    ax.bar(j, m, color='#c9d6ea', width=0.6, zorder=1)
    ax.text(j, 0.35, f'mean {m:.1f}', ha='center', va='bottom', fontsize=9)
    for n, k in enumerate(LISTENERS):
        v = vals(part='A', item=t, attribute='overall', listener=k)
        ax.plot(j - 0.15 + 0.15 * n, v[0], 'o', color=COLORS[k[-1]], zorder=3,
                label=f'{SEAT[k[-1]]} seat' if j == 0 else None)
ax.set_xticks(range(4), [f'{i + 1}: {n}' for i, n in enumerate(TRACK_NAMES)])
ax.set_ylim(0, 10.5); ax.set_ylabel('overall, 0-10'); ax.legend(loc='lower right', fontsize=8)
ax.set_title('Part A: overall sound quality per track (bar = mean)')
fig.savefig(HERE / 'fig_A_overall.png'); plt.close(fig)

# 2. Part A attribute profile: 1-5 scales and the two bipolar scales
fig, (a1, a2) = plt.subplots(1, 2, figsize=(7.6, 3.2), gridspec_kw={'width_ratios': [4, 2]})
five = [('bass_quality', 'bass\nquality'), ('natural', 'midrange\nnatural'), ('treble_smooth', 'treble\nsmooth'),
        ('clarity', 'clarity')]
mk = ['o', 's', '^', 'D']
for j, (a, lab) in enumerate(five):
    for i, t in enumerate(TRACKS):
        a1.plot(j - 0.22 + 0.15 * i, ms(vals(part='A', item=t, attribute=a))[0], mk[i], color='0.35',
                label=f'track {i + 1}' if j == 0 else None)
    a1.hlines(ms(vals(part='A', attribute=a))[0], j - 0.32, j + 0.32, color='k', lw=2)
a1.set_xticks(range(4), [l for _, l in five]); a1.set_ylim(1, 5); a1.set_ylabel('mean, 1 (worst) to 5 (best)')
a1.legend(fontsize=7, ncol=2, loc='lower left'); a1.set_title('Part A: 1-5 scales (bar = all tracks)')
for j, (a, lab) in enumerate([('bass_amount', 'bass\namount'), ('treble_amount', 'treble\namount')]):
    for i, t in enumerate(TRACKS):
        a2.plot(j - 0.22 + 0.15 * i, ms(vals(part='A', item=t, attribute=a))[0], mk[i], color='0.35')
    a2.hlines(ms(vals(part='A', attribute=a))[0], j - 0.32, j + 0.32, color='k', lw=2)
a2.axhline(0, color='green', lw=1); a2.set_xticks(range(2), ['bass\namount', 'treble\namount'])
a2.set_ylim(-2, 2); a2.set_yticks([-2, -1, 0, 1, 2], ['too little', '', 'just right', '', 'too much'])
a2.set_title('bipolar scales')
fig.tight_layout(); fig.savefig(HERE / 'fig_A_profile.png'); plt.close(fig)

# 3. Part B: overall and bass amount against woofer gain, one line per listener
fig, (b1, b2) = plt.subplots(1, 2, figsize=(7.6, 3.0))
for k in LISTENERS:
    for axx, a in ((b1, 'overall'), (b2, 'bass_amount')):
        y = [ms(vals(part='B', condition=c, attribute=a, listener=k))[0] for c in 'LDH']
        axx.plot([B_GAIN[c] for c in 'LDH'], y, 'o-', color=COLORS[k[-1]], alpha=0.75, label=f'{SEAT[k[-1]]} seat')
for axx, a in ((b1, 'overall'), (b2, 'bass_amount')):
    y = [ms(vals(part='B', condition=c, attribute=a))[0] for c in 'LDH']
    axx.plot([B_GAIN[c] for c in 'LDH'], y, 'k-', lw=2.5, label='mean')
    axx.set_xticks([-7.8, -5.8, -3.8], ['-7.8\n(L)', '-5.8\n(D, design)', '-3.8\n(H)'])
    axx.set_xlabel('woofer level, MiniDSP Out 1 [dB]')
b1.set_ylim(4, 10); b1.set_ylabel('overall, 0-10'); b1.set_title('Part B: overall'); b1.legend(fontsize=7)
b2.set_ylim(-2, 2); b2.axhline(0, color='green', lw=1)
b2.set_yticks([-2, -1, 0, 1, 2], ['too little', '', 'just right', '', 'too much']); b2.set_title('Part B: bass amount')
fig.tight_layout(); fig.savefig(HERE / 'fig_B_woofer.png'); plt.close(fig)

# 4. Part C: paired Rp 8.2 vs 3.3 per listener
fig, axs = plt.subplots(1, 3, figsize=(7.6, 2.8))
for axx, (a, lab, lim) in zip(axs, [('overall', 'overall, 0-10', (4, 10)), ('treble_amount', 'treble amount', (-2, 2)),
                                     ('treble_smooth', 'treble smoothness, 1-5', (1, 5))]):
    for k in LISTENERS:
        y = [ms(vals(part='C', condition=c, attribute=a, listener=k))[0] for c in ('R8', 'R3')]
        off = (LISTENERS.index(k) - 1) * 0.04
        axx.plot([0 + off, 1 + off], y, 'o-', color=COLORS[k[-1]], alpha=0.8, label=f'{SEAT[k[-1]]} seat')
    axx.plot([0, 1], [ms(vals(part='C', condition=c, attribute=a))[0] for c in ('R8', 'R3')], 'k-', lw=2.5,
             label='mean')
    axx.set_xticks([0, 1], ['Rp 8.2 Ω\n(design Rp)', 'Rp 3.3 Ω\n(−2.9 dB)']); axx.set_xlim(-0.3, 1.3)
    axx.set_ylim(*lim); axx.set_title(lab, fontsize=9)
axs[1].axhline(0, color='green', lw=1)
axs[0].legend(fontsize=7, loc='lower right')
fig.suptitle('Part C: tweeter level (track 4, then track 2); woofer left at −3.8 dB for both', fontsize=10)
fig.tight_layout(); fig.savefig(HERE / 'fig_C_tweeter.png'); plt.close(fig)
print('figures written')
