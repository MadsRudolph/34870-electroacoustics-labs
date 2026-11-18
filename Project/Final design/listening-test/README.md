# Listening test (Task 4), IEC listening room

| File | What |
|---|---|
| `ListeningTest_Operator.pdf` | readiness checklist, electrical check, roles, procedure, sample orders, what to do afterwards. Stays **outside** the room |
| `ListeningTest_Questionnaire.pdf` | the listener sheet (2 pages, print one per listener + spares) |
| `check_tones/` | 100 Hz, 325 Hz, 1 kHz sines at -12 dBFS for the multimeter check of the MiniDSP filters |
| `results_template.csv` | columns for typing in the sheets (one row per answer) |
| `make_excerpts.py` | cuts the four 90 s test excerpts from the vinyl rips (dual mono, -23 LUFS): `python3 make_excerpts.py <folder>`. Music stays out of git |
| `qr_form.png` | QR code for the phone form |
| `web/` | the phone form at **https://listening.madsrudolph.dev** (Cloudflare Worker + KV). Results: `https://listening.madsrudolph.dev/results?key=<web/.admin-key>`, CSV at `/results.csv?key=...`, with the blind conditions filled in |

Deploy the form after a change: `cd web && "../../../../../../Study Bench/node_modules/.bin/wrangler" deploy`
(any wrangler 4 that is logged in works). The admin key is a Worker secret (`wrangler secret put ADMIN_KEY`);
the local copy in `web/.admin-key` is gitignored, as is `web/.dev.vars` for `wrangler dev`.

Settings for the test: MiniDSP from `../data/dsp/MiniDSP_*.txt` (Output 2 holds the high-pass **once**),
Out 1 -5.8 dB, Out 2 0 dB, Rp 8.2 ohm, one vent open at 160 mm. Background:
`../lab-day/results_2026-11-12/LabDay_12Nov_Results.pdf`.

Rebuild a PDF: `~/.local/bin/tectonic -X compile <file>.tex`.
