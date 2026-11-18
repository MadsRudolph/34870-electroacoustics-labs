// Listening test (34870, Group 10, System D): stores questionnaire answers in KV and shows the results.
//   POST /api/submit                 one listener's answers (from public/index.html)
//   GET  /results?key=ADMIN_KEY      summary page for the day (means per condition, consistency check)
//   GET  /results.csv?key=ADMIN_KEY  long-format CSV, same columns as ../results_template.csv (+ id, submitted)
// The blind sample orders below must match the table in ListeningTest_Operator.pdf.

const ORDER_B = { // listener row -> condition of samples 1..4 (Out 1 gain: L -7.8, D -5.8, H -3.8 dB)
  1: ['D', 'L', 'D', 'H'], 2: ['H', 'D', 'L', 'D'], 3: ['D', 'H', 'L', 'D'],
  4: ['L', 'D', 'H', 'D'], 5: ['D', 'H', 'D', 'L'], 6: ['D', 'L', 'H', 'D'],
};
const ORDER_C = { // listener row -> [X, Y] (R8 = Rp 8.2 ohm, R3 = Rp 3.3 ohm)
  1: ['R8', 'R3'], 2: ['R3', 'R8'], 3: ['R8', 'R3'], 4: ['R3', 'R8'], 5: ['R8', 'R3'], 6: ['R3', 'R8'],
};
const row = n => ((n - 1) % 6) + 1;

const A_ATTR = { bass_amount: [-2, 2], bass_quality: [1, 5], natural: [1, 5], treble_amount: [-2, 2], treble_smooth: [1, 5], clarity: [1, 5], overall: [0, 10] };
const B_ATTR = { bass_amount: [-2, 2], overall: [0, 10] };
const C_ATTR = { treble_amount: [-2, 2], treble_smooth: [1, 5], overall: [0, 10] };
const TRACKS = ['track1', 'track2', 'track3', 'track4'];
const SAMPLES_B = ['sample1', 'sample2', 'sample3', 'sample4'];

export default {
  async fetch(req, env) {
    const url = new URL(req.url);
    if (url.pathname === '/api/submit' && req.method === 'POST') return submit(req, env);
    if (url.pathname === '/results' || url.pathname === '/results.csv') {
      if (!env.ADMIN_KEY || url.searchParams.get('key') !== env.ADMIN_KEY) return new Response('Not found', { status: 404 });
      const subs = await loadAll(env);
      if (url.pathname === '/results.csv') return new Response(toCsv(subs), { headers: {
        'content-type': 'text/csv; charset=utf-8', 'content-disposition': 'attachment; filename="listening_results.csv"', 'cache-control': 'no-store' } });
      return new Response(summaryHtml(subs, url.searchParams.get('key')), { headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } });
    }
    return env.ASSETS.fetch(req);
  },
};

const json = (obj, status = 200) => new Response(JSON.stringify(obj), { status, headers: { 'content-type': 'application/json', 'cache-control': 'no-store' } });

async function submit(req, env) {
  const text = await req.text();
  if (text.length > 20000) return json({ ok: false, error: 'too large' }, 413);
  let body; try { body = JSON.parse(text); } catch { return json({ ok: false, error: 'bad json' }, 400); }
  const a = body && body.answers;
  const r = validate(a);
  if (r) return json({ ok: false, error: r }, 400);
  const clean = sanitize(a);
  const id = `${Date.now().toString(36)}-${crypto.randomUUID().slice(0, 8)}`;
  const rec = { id, submitted: new Date().toISOString(), answers: clean };
  await env.RESP.put(`r:${id}`, JSON.stringify(rec));
  return json({ ok: true, id });
}

function inRange(v, [lo, hi]) { return Number.isInteger(v) && v >= lo && v <= hi; }
function validate(a) {
  if (!a || typeof a !== 'object') return 'no answers';
  if (!inRange(a.listener, [1, 200])) return 'listener number';
  for (const k of ['hearing', 'experience', 'group_member']) if (typeof a[k] !== 'string') return k;
  for (const t of TRACKS) for (const [k, rg] of Object.entries(A_ATTR)) if (!inRange(a[`A_${t}_${k}`], rg)) return `A ${t} ${k}`;
  for (const s of SAMPLES_B) for (const [k, rg] of Object.entries(B_ATTR)) if (!inRange(a[`B_${s}_${k}`], rg)) return `B ${s} ${k}`;
  if (a.C_run !== 'no') for (const s of ['X', 'Y']) for (const [k, rg] of Object.entries(C_ATTR)) if (!inRange(a[`C_${s}_${k}`], rg)) return `C ${s} ${k}`;
  return null;
}
function sanitize(a) {
  const out = {};
  for (const [k, v] of Object.entries(a)) {
    if (!/^[A-Za-z0-9_]{1,40}$/.test(k)) continue;
    if (typeof v === 'number' && Number.isFinite(v)) out[k] = v;
    else if (typeof v === 'string') out[k] = v.slice(0, 1000);
  }
  return out;
}

async function loadAll(env) {
  const subs = []; let cursor;
  do {
    const page = await env.RESP.list({ prefix: 'r:', cursor });
    const vals = await Promise.all(page.keys.map(k => env.RESP.get(k.name, 'json')));
    subs.push(...vals.filter(Boolean));
    cursor = page.list_complete ? undefined : page.cursor;
  } while (cursor);
  subs.sort((x, y) => x.submitted.localeCompare(y.submitted));
  return subs;
}

// One row per answer, with the blind condition filled in from the order tables.
function rows(subs) {
  const out = [];
  for (const s of subs) {
    const a = s.answers, n = a.listener, rw = row(n);
    const base = { id: s.id, submitted: s.submitted, listener: n, date: s.submitted.slice(0, 10), group_member: a.group_member,
      experience: a.experience, hearing: a.hearing === 'yes' ? `yes: ${a.hearing_note || ''}` : a.hearing };
    const push = (part, item, condition, attribute, score) => out.push({ ...base, part, item, condition, attribute, score });
    for (const t of TRACKS) for (const k of Object.keys(A_ATTR)) push('A', t, 'D_R8', k, a[`A_${t}_${k}`]);
    if (a.A_note) push('A', 'note', 'D_R8', 'comment', a.A_note);
    SAMPLES_B.forEach((smp, i) => {
      for (const k of Object.keys(B_ATTR)) push('B', smp, ORDER_B[rw][i], k, a[`B_${smp}_${k}`]);
      if (a[`B_comment_${smp}`]) push('B', smp, ORDER_B[rw][i], 'comment', a[`B_comment_${smp}`]);
    });
    if (a.B_best != null) push('B', 'best', a.B_best === 'no difference' ? 'none' : ORDER_B[rw][Number(a.B_best) - 1], 'best_sample', a.B_best);
    if (a.C_run !== 'no') {
      ['X', 'Y'].forEach((smp, i) => { for (const k of Object.keys(C_ATTR)) push('C', smp, ORDER_C[rw][i], k, a[`C_${smp}_${k}`]); });
      if (a.C_pref) push('C', 'preference', a.C_pref === 'no difference' ? 'none' : ORDER_C[rw][a.C_pref === 'X' ? 0 : 1], 'preferred', a.C_pref);
    }
    if (a.last_change) push('end', 'last', '', 'comment', a.last_change);
  }
  return out;
}

const COLS = ['listener', 'date', 'group_member', 'experience', 'hearing', 'part', 'item', 'condition', 'attribute', 'score', 'id', 'submitted'];
const csvCell = v => { const s = v == null ? '' : String(v); return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
function toCsv(subs) { return [COLS.join(','), ...rows(subs).map(r => COLS.map(c => csvCell(r[c])).join(','))].join('\n') + '\n'; }

// ---------- summary page ----------
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
function stats(xs) {
  const v = xs.filter(x => typeof x === 'number');
  if (!v.length) return { n: 0, m: '–', sd: '–' };
  const m = v.reduce((s, x) => s + x, 0) / v.length;
  const sd = v.length > 1 ? Math.sqrt(v.reduce((s, x) => s + (x - m) ** 2, 0) / (v.length - 1)) : 0;
  return { n: v.length, m: m.toFixed(2), sd: sd.toFixed(2) };
}
const cell = st => `<td>${st.m}<span class="sd"> ± ${st.sd}</span></td>`;

function summaryHtml(subs, key) {
  const R = rows(subs).filter(r => r.attribute !== 'comment');
  const pick = (f) => R.filter(f).map(r => r.score);
  const listeners = subs.map(s => s.answers.listener);
  const dupes = [...new Set(listeners.filter((n, i) => listeners.indexOf(n) !== i))];

  const aRows = Object.keys(A_ATTR).map(k => `<tr><th>${k}</th>${TRACKS.map(t => cell(stats(pick(r => r.part === 'A' && r.item === t && r.attribute === k)))).join('')}
    ${cell(stats(pick(r => r.part === 'A' && r.attribute === k)))}</tr>`).join('');
  const bRows = ['L', 'D', 'H'].map(c => `<tr><th>${c} <span class="sd">${{ L: 'Out 1 −7.8 dB', D: '−5.8 dB (design)', H: '−3.8 dB' }[c]}</span></th>
    ${cell(stats(pick(r => r.part === 'B' && r.condition === c && r.attribute === 'overall')))}
    ${cell(stats(pick(r => r.part === 'B' && r.condition === c && r.attribute === 'bass_amount')))}
    <td>${R.filter(r => r.part === 'B' && r.attribute === 'best_sample' && r.condition === c).length}</td></tr>`).join('');
  const bNone = R.filter(r => r.part === 'B' && r.attribute === 'best_sample' && r.condition === 'none').length;
  const cRows = ['R8', 'R3'].map(c => `<tr><th>${c} <span class="sd">${c === 'R8' ? 'Rp 8.2 Ω' : 'Rp 3.3 Ω'}</span></th>
    ${cell(stats(pick(r => r.part === 'C' && r.condition === c && r.attribute === 'overall')))}
    ${cell(stats(pick(r => r.part === 'C' && r.condition === c && r.attribute === 'treble_amount')))}
    ${cell(stats(pick(r => r.part === 'C' && r.condition === c && r.attribute === 'treble_smooth')))}
    <td>${R.filter(r => r.part === 'C' && r.attribute === 'preferred' && r.condition === c).length}</td></tr>`).join('');
  const cNone = R.filter(r => r.part === 'C' && r.attribute === 'preferred' && r.condition === 'none').length;

  const perL = subs.map(s => {
    const a = s.answers, rw = row(a.listener);
    const dIdx = ORDER_B[rw].map((c, i) => c === 'D' ? i : -1).filter(i => i >= 0);
    const d = dIdx.map(i => a[`B_sample${i + 1}_overall`]);
    const diff = Math.abs(d[0] - d[1]);
    const meanA = stats(TRACKS.map(t => a[`A_${t}_overall`])).m;
    return `<tr><td>${a.listener}</td><td>${rw}</td><td>${esc(a.group_member)}</td><td>${esc(a.experience)}</td><td>${meanA}</td>
      <td>${d.join(' / ')}</td><td class="${diff > 3 ? 'bad' : ''}">${diff}${diff > 3 ? ' (inconsistent)' : ''}</td>
      <td>${a.C_run === 'no' ? 'skipped' : esc(a.C_pref)}</td><td class="sd">${esc(s.submitted.slice(11, 16))} UTC</td></tr>`;
  }).join('');
  const comments = rows(subs).filter(r => r.attribute === 'comment').map(r =>
    `<li><b>L${r.listener}</b> <span class="sd">${r.part} ${r.item}${r.condition ? ' · ' + r.condition : ''}</span>: ${esc(r.score)}</li>`).join('');

  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Listening Test Results</title><style>
:root{--bg:#fff;--text:#1b1c1e;--muted:#666a70;--line:#dcdde0;--bad:#b3261e;--accent:#1f5fbf}
@media (prefers-color-scheme:dark){:root{--bg:#141517;--text:#ececee;--muted:#9a9ca3;--line:#34363b;--bad:#ff8a80;--accent:#6aa3ff}}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.45 system-ui,sans-serif}main{max-width:900px;margin:0 auto;padding:16px}
table{border-collapse:collapse;width:100%;margin:8px 0 18px;font-variant-numeric:tabular-nums}th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;white-space:nowrap}
.wrap{overflow-x:auto}.sd{color:var(--muted);font-size:12px}.bad{color:var(--bad);font-weight:600}h2{margin:22px 0 4px;font-size:18px}
a{color:var(--accent)}p{margin:4px 0}</style></head><body><main>
<h1>Listening test results</h1>
<p>${subs.length} submission(s). Values are mean ± standard deviation. Amount scales: −2 far too little, 0 just right, +2 far too much.
<a href="/results.csv?key=${encodeURIComponent(key)}">Download CSV</a> · reload the page for new answers.</p>
${dupes.length ? `<p class="bad">Listener number used more than once: ${dupes.join(', ')}. Check the sheets; both submissions are kept.</p>` : ''}
<h2>Part A · the design (Out 1 −5.8 dB, Rp 8.2 Ω)</h2><div class="wrap"><table><tr><th></th>${TRACKS.map(t => `<th>${t}</th>`).join('')}<th>all tracks</th></tr>${aRows}</table></div>
<h2>Part B · woofer level</h2><div class="wrap"><table><tr><th>condition</th><th>overall 0–10</th><th>bass amount</th><th>chosen best</th></tr>${bRows}
<tr><th>no difference</th><td></td><td></td><td>${bNone}</td></tr></table></div>
<p class="sd">Keep −5.8 dB if D's bass amount is near 0 and D scores at least as well as L and H.</p>
<h2>Part C · tweeter level</h2><div class="wrap"><table><tr><th>condition</th><th>overall 0–10</th><th>treble amount</th><th>treble smoothness</th><th>preferred</th></tr>${cRows}
<tr><th>no difference</th><td></td><td></td><td></td><td>${cNone}</td></tr></table></div>
<h2>Per listener</h2><div class="wrap"><table><tr><th>listener</th><th>order row</th><th>group</th><th>experience</th><th>Part A overall</th><th>D repeat scores</th><th>|difference|</th><th>Part C pref.</th><th>sent</th></tr>${perL}</table></div>
<h2>Comments</h2><ul>${comments || '<li class="sd">none yet</li>'}</ul>
</main></body></html>`;
}
