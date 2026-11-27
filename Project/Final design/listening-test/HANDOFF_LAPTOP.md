# Handoff to the laptop: solo listening test with MiniDSP over USB (27-Nov-2026)

Paste the prompt below into Claude Code on the laptop, started in `~/DTU/5. Semester/Electroacoustics/Labs`.

---

You're on Mads's laptop. It is the PC that sits **outside the IEC listening room** during the 34870
listening test. It plays the music, drives the school's **MiniDSP 2x4 HD** over USB, and is driven
from Mads's phone while he sits inside **alone**. Mads relies on you for all the technical steps:
explain in plain terms and do the work yourself. Never add AI attribution to commits.

Everything lives in the labs repo (its own git repo, NOT synced by Syncthing):
`Project/Final design/listening-test/`. Read `control-panel/README.md` first, especially the
sections "MiniDSP gains over USB", "First hardware check" and "Solo round".

## 1. Get the code and the secret

1. `git pull` in the labs repo. The latest commit adds the solo round (on the desktop, 27-Nov). If
   `control-panel/tests/test_solo.py` is missing, the desktop work has not been pushed: stop and ask Mads.
2. The admin key `web/.admin-key` is gitignored. The panel needs it to reach the server. If it is not
   on the laptop, ask Mads to copy it from the desktop (`~/DTU/5. Semester/Electroacoustics/Labs/Project/Final design/listening-test/web/.admin-key`),
   e.g. with `scp` over the LAN/Tailscale. Do NOT make a new key: that would change the results link.
   Never print the key.
3. `cd control-panel && python3 -m unittest discover -s tests`: expect 47 tests, all OK.

## 2. Deploy the phone form (pending since the desktop session)

The Worker gained a Durable Object (`SoloRoom`, migration `v1` in `web/wrangler.jsonc`) and the
solo mode in `web/public/index.html`. It has **not** been deployed. Ask Mads before deploying, then:
`cd web && wrangler deploy` (any logged-in wrangler 4; `npx wrangler login` once if needed). Check:
`curl -s "https://listening.madsrudolph.dev/api/solo/phone?code=0000"` should answer JSON
"No solo round with this code", not 404 HTML.

## 3. Set up the MiniDSP software (minidsp-rs)

1. `bash control-panel/minidsp/setup_minidsp.sh`: installs minidsp-rs v0.1.12 (`minidsp`, `minidspd`)
   into `~/.local/bin`, copies the config. Make sure `~/.local/bin` is on PATH.
2. `bash control-panel/minidsp/setup_minidsp.sh --udev`: USB permission rule, needs sudo, so ask Mads
   to run it himself with `! bash …`. Then he unplugs and replugs the MiniDSP.
3. Don't run `minidspd` at the same time as the panel.
4. **First hardware check** (README), with the **amplifier off**: `lsusb | grep 2752` → `2752:0011`;
   `minidsp probe`; `minidsp --usb 2752:0011` (read-only status); then the two safe gain commands
   (`output 0 gain -- -5.8`, `output 1 gain -- 0`). This has **never been run on real hardware**:
   write down the real outputs and error texts, whether the udev rule was needed, and whether gains
   survive a power cycle, and put them in the README's open points.
5. Panel: `python3 control_panel.py`, Output view → tick *Apply test gains automatically* →
   *Check connection* → *Set design now*. Optional *Load System D filters* (amp down; check it
   acoustically afterwards as the README says).
6. Time two gain sets in a row (`time minidsp --usb 2752:0011 output 0 gain -- -5.8` twice). The solo
   round starts every sample a fixed **2.5 s** after the tap so changed and unchanged levels can't be
   told apart. If one set of both outputs takes longer than about 2 s, raise `SoloLink.LEAD` in
   `control_panel.py` and tell Mads.

## 4. Rehearse the solo round

- Silent rehearsal: `python3 control_panel.py --test` (simulated MiniDSP), Solo view → Start solo
  round → open listening.madsrudolph.dev on a phone → "Solo: my phone runs the PC" → code. Then for
  real with the amp at a low level. The real tracks are Spotify streams (Tracks view); Spotify must be
  logged in and the Modi set as the system output.
- The laptop must not suspend or lock during the round (charger in). Check with Mads how Omarchy's
  idle/lock is set and turn it off for the session.
- The results page (`/results?key=…`) shows solo listeners as `<n>S` with their decoded order.
  Mads must not open it during a round.

## 5. Unfinished: "Tune by ear" from the phone (Mads asked for it, desktop session stopped halfway)

Goal: in the room, Mads sets Out 1 / Out 2 by hand from his phone while music plays, and can save a
setting he likes. Already written but **not tested and not deployed**:
- Worker: phone command `{code, action:'gain', out1, out2}` (Out 1 −18..0, Out 2 −6..0 dB, 0.5 dB
  steps), `{action:'pick', out1, out2, track, note}` (saved to KV `pick:*`, shown on the results page
  and in the CSV as part `tune`), and play items `T1..T4` (a track without touching the gains).
- Panel: `MiniDSPControl.set_manual` (separate range check, the blind levels stay locked),
  `SoloLink._gain` (sets live, also while music plays), `SoloLink._play_tune` (puts the design back
  first if the last gain came from a blind sample). The panel reports `state.gain` to the phone only
  for manual or design gains, never after a Part B sample.

Still to do:
1. Write `web/public/tune.html`: same look as `index.html`; code from `?code=` or the form's
   localStorage draft (`lt-draft-v1` → `answers.solo_code`); big Out 1 readout with −1 / −0.5 / +0.5 / +1
   and a slider; Out 2 the same; a "Design −5.8 / 0" button; Track 1–4 play buttons and Stop; status
   from `/api/solo/phone` (`panel.gain`, shown as "confirmed" when it equals the request); "Save as my
   pick" with an optional note; the list of saved picks. Link to it from the form's solo intro and review pages.
2. `control-panel/panel.html`: add T1–T4 to `ITEM_NAME`.
3. Tests in `tests/test_solo.py`: manual range (refuse +0.5, −18.5, 0.3), live gain while playing
   keeps reporting "playing", gain hidden (`None`) after a B item, tune play after a B item resets to
   the design, rapid gain taps only apply the last.
4. Run the worker with `wrangler dev` and the panel with
   `LISTENING_BASE=http://localhost:8787 python3 control_panel.py --test` and click through it.
5. README "Solo round": add the tune page. Then commit (no AI trailers), ask before deploying, deploy.

## Not in scope

Part C (Rp swap) can't be run solo; leave it out. Don't change the group-session flow (Steps view,
`ORDER_B` tables) or the blind levels −11.6 / −5.8 / 0.
