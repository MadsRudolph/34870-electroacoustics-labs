// Listening test (34870, Group 10, System D): stores questionnaire answers in KV and shows the results.
//   POST /api/submit                 one listener's answers (from public/index.html)
// Three listeners sit in the room at once (seats L, M, R), so the sample order belongs to the SESSION:
// order row = ((session - 1) mod 6) + 1. A listener is identified as <session><seat>, e.g. 3M.
//   GET  /results?key=ADMIN_KEY      summary page for the day (means per condition, consistency check)
//   GET  /results.csv?key=ADMIN_KEY  long-format CSV, same columns as ../results_template.csv (+ id, submitted)
// Solo rounds (one listener, nobody outside to change settings): the control panel on the PC by the room
// sets the MiniDSP over USB, and the listener's phone drives it through the SoloRoom Durable Object below.
//   POST /api/solo/new?key=…   panel: start a round (random Part B order, 4-digit code). Seat 'S', listener '<n>S'
//   POST /api/solo/panel?key=… panel: report its state, get the round (with the order) and the phone's command
//   POST /api/solo/end?key=…   panel: end the round
//   GET  /api/solo/phone?code= phone: the round's plan and the panel's state (never the order)
//   POST /api/solo/cmd          phone: {code, action: play|stop, item: A1..A4|B1..B4|T1..T4}
//                               tune page (/tune.html): {code, action: gain, out1, out2}  |  {code, action: pick, out1, out2, track, note}
// T1..T4 play a track without touching the gains; "gain" sets them by hand (Out 1 -18..0, Out 2 -6..0 dB, 0.1 dB steps).
// The panel reports a gain to the phone only when it was set by hand or is the design, never after a blind sample.
// The blind sample orders below must match the table in ListeningTest_Operator.pdf.

const ORDER_B = { // order row -> condition of samples 1..4 (Out 1 gain: L -11.6, D -5.8, H 0 dB from test 3 on;
                   // tests 1 and 2, 18 and 26 Nov 2026: L -7.8, D -5.8, H -3.8 dB)
  1: ['D', 'L', 'D', 'H'], 2: ['H', 'D', 'L', 'D'], 3: ['D', 'H', 'L', 'D'],
  4: ['L', 'D', 'H', 'D'], 5: ['D', 'H', 'D', 'L'], 6: ['D', 'L', 'H', 'D'],
};
const ORDER_C = { // order row -> [X, Y] (R8 = Rp 8.2 ohm, R3 = Rp 3.3 ohm)
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
    if (url.pathname.startsWith('/api/solo/')) return solo(req, env, url);
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

// ---------- solo rounds ----------
const SOLO_ADMIN = ['/api/solo/new', '/api/solo/panel', '/api/solo/end'];
async function solo(req, env, url) {
  const admin = SOLO_ADMIN.includes(url.pathname);
  if (admin && (!env.ADMIN_KEY || url.searchParams.get('key') !== env.ADMIN_KEY)) return json({ ok: false, error: 'not found' }, 404);
  if (!['/api/solo/phone', '/api/solo/cmd', ...SOLO_ADMIN].includes(url.pathname)) return json({ ok: false, error: 'not found' }, 404);
  const stub = env.SOLO.get(env.SOLO.idFromName('solo'));
  const res = await stub.fetch(new Request(req.url, { method: req.method, headers: req.headers, body: req.method === 'POST' ? await req.text() : undefined }));
  if (url.pathname === '/api/solo/new' && res.ok) {                // keep the order for the results page
    const j = await res.clone().json();
    if (j.ok) await env.RESP.put(`solo:${j.round.id}`, JSON.stringify(j.round));
  }
  if (url.pathname === '/api/solo/cmd' && res.ok) {
    const j = await res.clone().json();
    if (j.ok && j.pick) await env.RESP.put(`pick:${j.pick.round}:${Date.now()}`, JSON.stringify(j.pick));
  }
  return res;
}

const SOLO_ITEMS = ['A1', 'A2', 'A3', 'A4', 'B1', 'B2', 'B3', 'B4', 'T1', 'T2', 'T3', 'T4'];
const GAIN_RANGE = { out1: [-18, 0], out2: [-6, 0] };          // the panel checks the same limits again
const okGain = (v, [lo, hi]) => typeof v === 'number' && Number.isFinite(v) && v >= lo && v <= hi && Math.abs(v * 10 - Math.round(v * 10)) < 1e-6;
function randInt(n) { const a = new Uint32Array(1); crypto.getRandomValues(a); return a[0] % n; }
function shuffled(xs) { const a = [...xs]; for (let i = a.length - 1; i > 0; i--) { const j = randInt(i + 1); [a[i], a[j]] = [a[j], a[i]]; } return a; }

// One shared room: at most one solo round runs at a time. Strongly consistent, unlike KV, so a tap on the
// phone reaches the panel within one poll (~0.7 s) wherever the two connect from.
export class SoloRoom {
  constructor(ctx) { this.ctx = ctx; this.s = null; }
  async load() {
    if (!this.s) this.s = (await this.ctx.storage.get('s')) || { nextN: 1, round: null, cmd: { seq: 0 }, panel: {}, panelSeen: 0, phoneSeen: 0, fails: [] };
    return this.s;
  }
  async save() { await this.ctx.storage.put('s', this.s); }
  async fetch(req) {
    const url = new URL(req.url), s = await this.load(), now = Date.now();
    const body = req.method === 'POST' ? await req.json().catch(() => ({})) : {};
    const p = url.pathname;
    if (p === '/api/solo/new' && req.method === 'POST') {
      const partA = body.partA !== false;
      const code = String(1000 + randInt(9000));
      s.round = { id: `${now.toString(36)}-${crypto.randomUUID().slice(0, 6)}`, n: s.nextN++, code, partA,
        order: shuffled(['D', 'D', 'L', 'H']), created: new Date(now).toISOString(), ended: false };
      s.cmd = { seq: 0 }; s.panel = {}; s.phoneSeen = 0; s.fails = [];
      await this.save();
      return json({ ok: true, round: s.round, cmd: s.cmd });
    }
    if (p === '/api/solo/panel' && req.method === 'POST') {
      s.panel = { ...(body.state || {}), t: now }; s.panelSeen = now;
      await this.save();
      return json({ ok: true, round: s.round, cmd: s.cmd, phone_age: s.phoneSeen ? (now - s.phoneSeen) / 1000 : null });
    }
    if (p === '/api/solo/end' && req.method === 'POST') {
      if (s.round) s.round.ended = true;
      await this.save();
      return json({ ok: true });
    }
    // phone: code check, with a lock-out after 10 wrong codes in 10 minutes
    s.fails = (s.fails || []).filter(t => now - t < 600000);
    if (s.fails.length >= 10) return json({ ok: false, error: 'Too many wrong codes. Wait a few minutes.' }, 429);
    const code = p === '/api/solo/phone' ? url.searchParams.get('code') : String(body.code || '');
    if (!s.round || code !== s.round.code) {
      s.fails.push(now); await this.save();
      return json({ ok: false, error: 'No solo round with this code. Check the code on the PC.' }, 404);
    }
    if (s.round.ended) return json({ ok: false, error: 'This solo round was ended on the PC.' }, 410);
    const r = s.round;
    if (p === '/api/solo/cmd' && req.method === 'POST') {
      const item = String(body.item || '');
      if (!['play', 'stop', 'gain', 'pick'].includes(body.action)) return json({ ok: false, error: 'action' }, 400);
      if (body.action === 'play' && (!SOLO_ITEMS.includes(item) || (!r.partA && item[0] === 'A'))) return json({ ok: false, error: 'item' }, 400);
      if (['gain', 'pick'].includes(body.action) && !(okGain(body.out1, GAIN_RANGE.out1) && okGain(body.out2, GAIN_RANGE.out2)))
        return json({ ok: false, error: 'Out 1 must be -18..0 dB and Out 2 -6..0 dB, in 0.1 dB steps' }, 400);
      if (body.action === 'pick') {                                // a setting the listener chose by ear: kept for the results
        const pick = { round: r.id, n: r.n, out1: body.out1, out2: body.out2, track: String(body.track || '').slice(0, 4),
          note: String(body.note || '').slice(0, 300), t: new Date(now).toISOString() };
        r.picks = [...(r.picks || []), pick];
        await this.save();
        return json({ ok: true, pick });
      }
      s.cmd = { seq: (s.cmd.seq || 0) + 1, action: body.action, item, t: now,
        ...(body.action === 'gain' ? { out1: body.out1, out2: body.out2 } : {}) };
    }
    s.phoneSeen = now;
    await this.save();
    const pn = s.panel || {};
    return json({ ok: true, id: r.id, n: r.n, partA: r.partA, cmd: { seq: s.cmd.seq, action: s.cmd.action, item: s.cmd.item },
      panel: { seq: pn.seq, state: pn.state, item: pn.item, msg: pn.msg, track: pn.track, elapsed: pn.elapsed, length: pn.length, gain: pn.gain },
      picks: (r.picks || []).map(({ out1, out2, track, note, t }) => ({ out1, out2, track, note, t })),
      panel_online: now - s.panelSeen < 8000 });
  }
}

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
  if (!inRange(a.session, [1, 100])) return 'session number';
  if (!['L', 'M', 'R', 'S'].includes(a.seat)) return 'seat';
  if (a.seat === 'S' && (typeof a.solo_id !== 'string' || !/^[a-z0-9-]{4,40}$/.test(a.solo_id))) return 'solo round';
  for (const k of ['hearing', 'experience', 'group_member']) if (typeof a[k] !== 'string') return k;
  if (!(a.seat === 'S' && a.A_run === 'no'))
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
  const solos = {};
  const sl = await env.RESP.list({ prefix: 'solo:' });
  (await Promise.all(sl.keys.map(k => env.RESP.get(k.name, 'json')))).filter(Boolean).forEach(r => { solos[r.id] = r; });
  SOLO_ROUNDS = solos;
  const pl = await env.RESP.list({ prefix: 'pick:' });
  PICKS = (await Promise.all(pl.keys.map(k => env.RESP.get(k.name, 'json')))).filter(Boolean).sort((x, y) => x.t.localeCompare(y.t));
  return subs;
}
let SOLO_ROUNDS = {}, PICKS = [];
// Part B order of a submission: group sessions from the table, solo rounds from their stored random order.
const orderB = a => a.seat === 'S' ? ((SOLO_ROUNDS[a.solo_id] || {}).order || ['?', '?', '?', '?']) : ORDER_B[row(a.session)];
const orderName = a => a.seat === 'S' ? 'solo ' + orderB(a).join('') : String(row(a.session));

// One row per answer, with the blind condition filled in from the order tables.
function rows(subs) {
  const out = [];
  for (const s of subs) {
    const a = s.answers, rw = row(a.session), ob = orderB(a);
    const base = { id: s.id, submitted: s.submitted, listener: `${a.session}${a.seat}`, session: a.session, seat: a.seat,
      date: s.submitted.slice(0, 10), group_member: a.group_member,
      experience: a.experience, hearing: a.hearing === 'yes' ? `yes: ${a.hearing_note || ''}` : a.hearing };
    const push = (part, item, condition, attribute, score) => out.push({ ...base, part, item, condition, attribute, score });
    if (a.A_run !== 'no') for (const t of TRACKS) for (const k of Object.keys(A_ATTR)) push('A', t, 'D_R8', k, a[`A_${t}_${k}`]);
    if (a.A_note) push('A', 'note', 'D_R8', 'comment', a.A_note);
    SAMPLES_B.forEach((smp, i) => {
      for (const k of Object.keys(B_ATTR)) push('B', smp, ob[i], k, a[`B_${smp}_${k}`]);
      if (a[`B_comment_${smp}`]) push('B', smp, ob[i], 'comment', a[`B_comment_${smp}`]);
      if (a[`solo_plays_${'B' + (i + 1)}`]) push('B', smp, ob[i], 'times_played', a[`solo_plays_${'B' + (i + 1)}`]);
    });
    if (a.B_best != null) push('B', 'best', a.B_best === 'no difference' ? 'none' : ob[Number(a.B_best) - 1], 'best_sample', a.B_best);
    if (a.C_run !== 'no') {
      ['X', 'Y'].forEach((smp, i) => { for (const k of Object.keys(C_ATTR)) push('C', smp, ORDER_C[rw][i], k, a[`C_${smp}_${k}`]); });
      if (a.C_pref) push('C', 'preference', a.C_pref === 'no difference' ? 'none' : ORDER_C[rw][a.C_pref === 'X' ? 0 : 1], 'preferred', a.C_pref);
    }
    if (a.last_change) push('end', 'last', '', 'comment', a.last_change);
  }
  return out;
}

const COLS = ['listener', 'session', 'seat', 'date', 'group_member', 'experience', 'hearing', 'part', 'item', 'condition', 'attribute', 'score', 'id', 'submitted'];
const csvCell = v => { const s = v == null ? '' : String(v); return /[",\n\r]/.test(s) ? `"${s.replace(/"/g, '""')}"` : s; };
function pickRows() {
  return PICKS.flatMap(p => ['out1', 'out2'].map(k => ({ listener: `${p.n}S`, session: p.n, seat: 'S', date: p.t.slice(0, 10), part: 'tune',
    item: p.track || 'pick', condition: p.note || '', attribute: `${k}_db`, score: p[k], submitted: p.t })));
}
function toCsv(subs) { return [COLS.join(','), ...[...rows(subs), ...pickRows()].map(r => COLS.map(c => csvCell(r[c])).join(','))].join('\n') + '\n'; }

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
  const R = rows(subs).filter(r => r.attribute !== 'comment' && r.attribute !== 'times_played');
  const pick = (f) => R.filter(f).map(r => r.score);
  const listeners = subs.map(s => `${s.answers.session}${s.answers.seat}`);
  const dupes = [...new Set(listeners.filter((n, i) => listeners.indexOf(n) !== i))];

  const aRows = Object.keys(A_ATTR).map(k => `<tr><th>${k}</th>${TRACKS.map(t => cell(stats(pick(r => r.part === 'A' && r.item === t && r.attribute === k)))).join('')}
    ${cell(stats(pick(r => r.part === 'A' && r.attribute === k)))}</tr>`).join('');
  const bRows = ['L', 'D', 'H'].map(c => `<tr><th>${c} <span class="sd">${{ L: 'Out 1 −11.6 dB (−7.8 before 27 Nov)', D: '−5.8 dB (design)', H: '0 dB (−3.8 before 27 Nov)' }[c]}</span></th>
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
    const a = s.answers;
    const dIdx = orderB(a).map((c, i) => c === 'D' ? i : -1).filter(i => i >= 0);
    const d = dIdx.map(i => a[`B_sample${i + 1}_overall`]);
    const diff = Math.abs(d[0] - d[1]);
    const meanA = a.A_run === 'no' ? 'skipped' : stats(TRACKS.map(t => a[`A_${t}_overall`])).m;
    return `<tr><td>${a.session}${esc(a.seat)}</td><td>${esc(orderName(a))}</td><td>${esc(a.group_member)}</td><td>${esc(a.experience)}</td><td>${meanA}</td>
      <td>${d.join(' / ')}</td><td class="${diff > 3 ? 'bad' : ''}">${diff}${diff > 3 ? ' (inconsistent)' : ''}</td>
      <td>${a.C_run === 'no' ? 'skipped' : esc(a.C_pref)}</td><td class="sd">${esc(s.submitted.slice(11, 16))} UTC</td></tr>`;
  }).join('');
  const comments = rows(subs).filter(r => r.attribute === 'comment').map(r =>
    `<li><b>${esc(r.listener)}</b> <span class="sd">${r.part} ${r.item}${r.condition ? ' · ' + r.condition : ''}</span>: ${esc(r.score)}</li>`).join('');

  return `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex"><title>Listening Test Results</title><style>
:root{--bg:#fff;--text:#1b1c1e;--muted:#666a70;--line:#dcdde0;--bad:#b3261e;--accent:#1f5fbf}
@media (prefers-color-scheme:dark){:root{--bg:#141517;--text:#ececee;--muted:#9a9ca3;--line:#34363b;--bad:#ff8a80;--accent:#6aa3ff}}
body{margin:0;background:var(--bg);color:var(--text);font:15px/1.45 system-ui,sans-serif}main{max-width:900px;margin:0 auto;padding:16px}
table{border-collapse:collapse;width:100%;margin:8px 0 18px;font-variant-numeric:tabular-nums}th,td{border-bottom:1px solid var(--line);padding:6px 8px;text-align:left;white-space:nowrap}
.wrap{overflow-x:auto}.sd{color:var(--muted);font-size:12px}.bad{color:var(--bad);font-weight:600}h2{margin:22px 0 4px;font-size:18px}
a{color:var(--accent)}p{margin:4px 0}</style></head><body><main>
<h1>Listening test results</h1>
<p>${subs.length} submission(s). Seat S = a solo round (one listener, the panel set the MiniDSP; Part C not run). Values are mean ± standard deviation. Amount scales: −2 far too little, 0 just right, +2 far too much.
<a href="/results.csv?key=${encodeURIComponent(key)}">Download CSV</a> · reload the page for new answers.</p>
${dupes.length ? `<p class="bad">Session + seat used more than once: ${dupes.join(', ')}. Check the sheets; both submissions are kept.</p>` : ''}
<h2>Part A · the design (Out 1 −5.8 dB, Rp 8.2 Ω)</h2><div class="wrap"><table><tr><th></th>${TRACKS.map(t => `<th>${t}</th>`).join('')}<th>all tracks</th></tr>${aRows}</table></div>
<h2>By seat · overall 0–10</h2><p class="sd">Left and right sit off axis, so treble may read lower there.</p><div class="wrap"><table><tr><th>seat</th><th>Part A, all tracks</th><th>Part A treble amount</th><th>Part B, D samples</th></tr>${['L', 'M', 'R'].map(st => `<tr><th>${{ L: 'Left', M: 'Middle', R: 'Right' }[st]}</th>${cell(stats(pick(r => r.seat === st && r.part === 'A' && r.attribute === 'overall')))}${cell(stats(pick(r => r.seat === st && r.part === 'A' && r.attribute === 'treble_amount')))}${cell(stats(pick(r => r.seat === st && r.part === 'B' && r.condition === 'D' && r.attribute === 'overall')))}</tr>`).join('')}</table></div>
<h2>Part B · woofer level</h2><div class="wrap"><table><tr><th>condition</th><th>overall 0–10</th><th>bass amount</th><th>chosen best</th></tr>${bRows}
<tr><th>no difference</th><td></td><td></td><td>${bNone}</td></tr></table></div>
<p class="sd">Keep −5.8 dB if D's bass amount is near 0 and D scores at least as well as L and H.</p>
<h2>Part C · tweeter level</h2><div class="wrap"><table><tr><th>condition</th><th>overall 0–10</th><th>treble amount</th><th>treble smoothness</th><th>preferred</th></tr>${cRows}
<tr><th>no difference</th><td></td><td></td><td></td><td>${cNone}</td></tr></table></div>
<h2>Per listener</h2><div class="wrap"><table><tr><th>session + seat</th><th>order row</th><th>group</th><th>experience</th><th>Part A overall</th><th>D repeat scores</th><th>|difference|</th><th>Part C pref.</th><th>sent</th></tr>${perL}</table></div>
<h2>Tuning by ear (solo, chosen by hand, not blind)</h2>
<p class="sd">Settings the listener saved on the tune page. Design: Out 1 −5.8 dB, Out 2 0 dB.</p>
<div class="wrap"><table><tr><th>listener</th><th>Out 1</th><th>Out 2</th><th>track</th><th>note</th><th>saved</th></tr>${PICKS.map(p =>
  `<tr><td>${p.n}S</td><td>${p.out1} dB</td><td>${p.out2} dB</td><td>${esc(p.track)}</td><td>${esc(p.note)}</td><td class="sd">${esc(p.t.slice(0, 16).replace('T', ' '))} UTC</td></tr>`).join('') || '<tr><td colspan="6" class="sd">none yet</td></tr>'}</table></div>
<h2>Comments</h2><ul>${comments || '<li class="sd">none yet</li>'}</ul>
</main></body></html>`;
}
