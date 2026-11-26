"""Listening test 26 Nov 2026 (test 2): numbers and figures from the phone-form export.

    python3 analyze_listening.py            (reads listening_results_2026-11-26.csv next to this file)

Writes numbers.txt and fig_*.png into this folder. The CSV is the /results.csv export of
https://listening.madsrudolph.dev, rows dated 2026-11-26 only, with the blind conditions already
filled in. Copied from ../results_2026-11-18/analyze_listening.py; the 18-Nov folder is not touched.
At the end it compares with test 1 (reads ../results_2026-11-18/listening_results_2026-11-18.csv)
and writes fig_compare.png.
"""
import csv
import statistics as st
from pathlib import Path

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

HERE = Path(__file__).resolve().parent
DATE = '2026-11-26'
CSV = HERE / f'listening_results_{DATE}.csv'
CSV1 = HERE.parent / 'results_2026-11-18' / 'listening_results_2026-11-18.csv'   # test 1, read only
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
p('Listening test 2, 26 Nov 2026, IEC listening room, System D')
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
p('  PROVISIONAL: track 4 failed to play five times during the run (12:52, 13:09 twice, 13:10, 13:13);')
p('  which samples were heard with track 2 only or after retries is not known yet.')
p('  Woofer level during Part C not recorded; the operator sheet says Out 1 back to -5.8 dB after Part B')
p('  (Part B for this session ended on D, -5.8 dB, anyway).')
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
for axx, (a, lab, lim) in zip(axs, [('overall', 'overall, 0-10', (0, 10)), ('treble_amount', 'treble amount', (-2, 2)),
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
fig.suptitle('Part C: tweeter level (track 4, then track 2); PROVISIONAL, track 4 failed during the run', fontsize=10)
fig.tight_layout(); fig.savefig(HERE / 'fig_C_tweeter.png'); plt.close(fig)
print('figures written')

# ---------------- comparison with test 1 (18 Nov) ----------------
# Same speaker settings, same four tracks (track 2 was still Superstition), same orders table.
# Test 1 = session 1 (order row 1), test 2 = session 2 (order row 2).
R1 = list(csv.DictReader(open(CSV1, encoding='utf-8')))
GROUP = {r['listener'] for r in R if r['group_member'] == 'yes'}


def vals_in(rows, **kw):
    return [float(r['score']) for r in rows if all(r[k] == v for k, v in kw.items())]


def f2(v):
    m, s, n = ms(v)
    return f'{m:5.2f} (n={n:2d})'


cmp_out = ['', 'Comparison with test 1 (18 Nov, session 1, 3 listeners) -- test 1 | test 2 | both pooled',
           f'  group members in test 2: {", ".join(sorted(GROUP)) or "none"} (test 1: none)']
c = cmp_out.append
c('  Part A, all tracks:')
for a in A_ATTR:
    t1, t2 = vals_in(R1, part='A', attribute=a), vals_in(R, part='A', attribute=a)
    t2x = [float(r['score']) for r in R if r['part'] == 'A' and r['attribute'] == a and r['listener'] not in GROUP]
    c(f'    {a:14} {f2(t1)} | {f2(t2)} | {f2(t1 + t2)}    test 2 without group members {f2(t2x)}')
c('  Part A overall per track (test 1 | test 2):')
for i, t in enumerate(TRACKS):
    c(f'    track {i + 1} {TRACK_NAMES[i]:14} {f2(vals_in(R1, part="A", item=t, attribute="overall"))} | '
      f'{f2(vals_in(R, part="A", item=t, attribute="overall"))}')
c('  Part A treble smoothness on the vocal tracks 1+2 (test 1 | test 2): '
  f'{f2([v for t in TRACKS[:2] for v in vals_in(R1, part="A", item=t, attribute="treble_smooth")])} | '
  f'{f2([v for t in TRACKS[:2] for v in vals_in(R, part="A", item=t, attribute="treble_smooth")])}')
c('  Part B (test 1 | test 2 | pooled):')
for cnd in 'LDH':
    for a in ('overall', 'bass_amount'):
        t1, t2 = vals_in(R1, part='B', condition=cnd, attribute=a), vals_in(R, part='B', condition=cnd, attribute=a)
        c(f'    {cnd} {a:12} {f2(t1)} | {f2(t2)} | {f2(t1 + t2)}')
    b1 = sum(1 for r in R1 if r['part'] == 'B' and r['attribute'] == 'best_sample' and r['condition'] == cnd)
    b2 = sum(1 for r in R if r['part'] == 'B' and r['attribute'] == 'best_sample' and r['condition'] == cnd)
    c(f'    {cnd} chosen best   {b1} | {b2}')
c(f'    no difference chosen: {sum(1 for r in R1 if r["part"] == "B" and r["attribute"] == "best_sample" and r["condition"] == "none")}'
  f' | {sum(1 for r in R if r["part"] == "B" and r["attribute"] == "best_sample" and r["condition"] == "none")}')
c('  Part C (test 1 | test 2), PROVISIONAL for test 2. Test 1: X = R8, Y = R3, woofer -3.8 dB. Test 2: X = R3, Y = R8.')
for cnd in ('R8', 'R3'):
    for a in ('overall', 'treble_amount', 'treble_smooth'):
        c(f'    {cnd} {a:14} {f2(vals_in(R1, part="C", condition=cnd, attribute=a))} | '
          f'{f2(vals_in(R, part="C", condition=cnd, attribute=a))}')
    c(f'    {cnd} preferred      {sum(1 for r in R1 if r["part"] == "C" and r["attribute"] == "preferred" and r["condition"] == cnd)}'
      f' | {sum(1 for r in R if r["part"] == "C" and r["attribute"] == "preferred" and r["condition"] == cnd)}')
c('    order: R3 was played second in test 1 and first in test 2 and was preferred in both, so the '
  'preference is not only "the second sample"')
c('    test 2 treble amount is inverted (R3 +1.00, i.e. too much; R8 -1.67, too little) although R3 puts the '
  'tweeter 2.9 dB LOWER: check the track 4 failures and the Rp swap before using Part C')
with open(HERE / 'numbers.txt', 'a', encoding='utf-8') as fh:
    fh.write('\n'.join(cmp_out) + '\n')
print('\n'.join(cmp_out))

# figure: Part A attribute means and Part B curves, test 1 against test 2
fig, (c1, c2) = plt.subplots(1, 2, figsize=(7.8, 3.2), gridspec_kw={'width_ratios': [3, 2]})
five = ['bass_quality', 'natural', 'treble_smooth', 'clarity']
labs = ['bass\nquality', 'midrange\nnatural', 'treble\nsmooth', 'clarity', 'overall\n(0-10)/2']
for k, (rows, col, lab) in enumerate(((R1, '#2a6fdb', 'test 1, 18 Nov'), (R, '#d9822b', 'test 2, 26 Nov'))):
    y = [ms(vals_in(rows, part='A', attribute=a))[0] for a in five] + [ms(vals_in(rows, part='A', attribute='overall'))[0] / 2]
    e = [ms(vals_in(rows, part='A', attribute=a))[1] for a in five] + [ms(vals_in(rows, part='A', attribute='overall'))[1] / 2]
    c1.bar([j - 0.2 + 0.4 * k for j in range(5)], y, 0.38, yerr=e, color=col, alpha=0.8, label=lab, capsize=2)
    yb = [ms(vals_in(rows, part='B', condition=cnd, attribute='bass_amount'))[0] for cnd in 'LDH']
    c2.plot([B_GAIN[cnd] for cnd in 'LDH'], yb, 'o-', color=col, lw=2, label=lab)
c1.set_xticks(range(5), labs, fontsize=8); c1.set_ylim(1, 5.4); c1.set_ylabel('mean, 1-5 (bar: ±1 sd)')
c1.set_title('Part A, all tracks', fontsize=10); c1.legend(fontsize=7, loc='lower left')
c2.axhline(0, color='green', lw=1); c2.set_ylim(-2, 2)
c2.set_yticks([-2, -1, 0, 1, 2], ['too little', '', 'just right', '', 'too much'])
c2.set_xticks([-7.8, -5.8, -3.8], ['-7.8\n(L)', '-5.8\n(D)', '-3.8\n(H)']); c2.set_xlabel('woofer level, Out 1 [dB]')
c2.set_title('Part B: bass amount', fontsize=10); c2.legend(fontsize=7)
fig.tight_layout(); fig.savefig(HERE / 'fig_compare.png'); plt.close(fig)
print('comparison figure written')
