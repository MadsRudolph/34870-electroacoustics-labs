# Listening-test control panel

> **MiniDSP automation: setup on the PC in the listening room (status 27-Nov-2026).**
> The 2x4 HD gain automation is unit-tested (`python3 -m unittest discover -s tests`, 47 tests)
> and the CLI steps of the first hardware check **passed on the real box** from the laptop on
> 27-Nov-2026 (results under **First hardware check**). On a new PC:
> 1. `bash minidsp/setup_minidsp.sh` installs minidsp-rs v0.1.12 into `~/.local/bin` (no sudo).
> 2. `bash minidsp/setup_minidsp.sh --udev` installs the USB rule (sudo), then replug the MiniDSP.
> 3. Work through **First hardware check** below with the amplifier off (step 7 loads the crossover
>    without the official software), then tick
>    "MiniDSP automation" in the panel's Output view (the switch is saved per PC, default off).
> Open points to confirm on the hardware are listed under **MiniDSP troubleshooting**.

A small local web app for the operator outside the IEC listening room. It plays the four test
tracks (from the vinyl FLACs or from Spotify and other players), walks through each session
step by step with the blind orders, and plays the vinyl library or Spotify for casual listening.

## Start it

```
cd "5. Semester/Electroacoustics/Labs/Project/Final design/listening-test/control-panel"
python3 control_panel.py
```

The browser opens at <http://127.0.0.1:8771>. Leave the terminal open; **Ctrl+C** stops the panel
(and its player). If the browser tab is closed, just open the address again.

| Option | What it does |
|---|---|
| `--test` | silent: the player plays to a null output, nothing is heard. Use it to rehearse |
| `--no-browser` | do not open the browser |
| `--port 9000` | use another port (if 8771 is taken) |
| `--settings FILE` | use another settings file (default `panel_settings.json` here) |

Needs only what is already installed: Python 3, `mpv`, `ffmpeg`/`ffprobe`, `busctl`, `pactl`.
Optional: the `minidsp` program from minidsp-rs, for setting the MiniDSP gains over USB.

## The views (left sidebar)

- **Setup:** the checklist before the first session (signal chain, MiniDSP, the electrical check
  with **100 Hz / 325 Hz / 1 kHz check-tone buttons**, Rp and vent, level with track 4). Ticks
  are remembered in the browser.
- **Steps:** the main view during the test. Set the **session number** (three listeners per
  session). Each step says what to **SET** on the speaker, what to **PLAY** (one big play button)
  and what happens **AFTER**. The orders come from the operator sheet: order row
  = ((session − 1) mod 6) + 1. The full table is under "Show all orders". **Part D** (vent open
  vs both plugged, track 3) is a switch, off by default; it is not on the questionnaire yet.
- **Tracks:** the four test tracks. Per track: **Local** (a file from the vinyl library) or
  **Stream** (Spotify or another player), start and length (type `1:30` or `90`), and Part B /
  Part C sample buttons that play track 2 → 3 and 4 → 2 with a gap between them.
- **Library:** the vinyl albums: play an album or a track, seek by clicking the progress bar,
  previous and next in the bottom bar.
- **Players:** Spotify, Tidal or Qobuz in a browser, tidal-hifi … (anything that shows media
  controls): play/pause, next, previous, and an **Open Spotify** button.
- **Output:** which sound card is used, the library folder, the target loudness, and the
  **MiniDSP gains** switch (see "MiniDSP gains over USB" below).

The **bottom bar** always shows what plays, the time left, Pause, **+15 s / +30 s** (makes the
excerpt that plays now longer, this time only) and **Stop**. The sidebar shows the output
(green dot = the Schiit Modi, amber = something else) and the "Do not change" list.

## Keyboard

| Key | Action |
|---|---|
| `1` `2` `3` `4` | play test track 1–4 (stops whatever plays) |
| `B` | Part B sample: track 2, then track 3 |
| `C` | Part C sample: track 4, then track 2 |
| `Space` or `Esc` | stop |
| `P` | (Steps view) play the current step |
| `N` | (Steps view) next step |

Keys are ignored while you type in a field.

## What the panel does with local files and with streaming

**Local files are the most controllable source.** For a local file the panel cuts start and
length itself, fades 0.5 s in and out, levels it to **−23 LUFS** (measured with ffmpeg exactly
as `make_excerpts.py` does, cached in `loudness_cache.json`) and plays it **mono** (left = right),
so the MiniDSP only needs Input 1. The gains match `make_excerpts.py` to 0.1 dB.

For a **streaming** track the panel only controls start and length:
- **Spotify:** paste the track link (`https://open.spotify.com/track/…`) in the row. The panel
  tells Spotify to open it, jumps to the start time, and pauses it after the length.
- **Other players** (browser tabs, tidal-hifi): open the track in the player first; the panel
  plays whatever is loaded there, jumps to the start (if the player allows it) and pauses after
  the length.
- If the player ignores the jump, the row says so ("did not seek: starts at 0:00").
- The panel can **not** set the level, mono or fades of a stream. In Spotify: quality
  Lossless (or Very high), **Normalize volume on**, Crossfade / Automix / Equalizer **off**,
  volume 100 %. Level "Normal" is about −14 LUFS: fine if all four tracks come from Spotify. If
  Spotify and local tracks are mixed, use **"Quiet"** (about −23 LUFS), or the local tracks play
  about 9 dB quieter.
- Spotify is **stereo**: route MiniDSP **Input 1 and Input 2** to both outputs.
- Spotify and browsers always play to the **system default output**. Make the Modi the system
  default (Output view shows it).

Whenever the panel starts something, it pauses every other player, so two sources never play at
once.

## Files

| File | What |
|---|---|
| `control_panel.py` | the server: web page, mpv control, MPRIS (Spotify etc.), loudness |
| `panel.html` | the page |
| `panel_settings.json` | created on first start: the four tracks, gap, session and step, output device. Per machine, so gitignored; copy the start/length values into the report if they changed |
| `loudness_cache.json` | measured loudness and track lengths (can be deleted any time; gitignored) |
| `tests/` | `python3 -m unittest discover -s tests -v`: the MiniDSP control (every CLI call is mocked, no hardware needed) and the step/gain table (needs `node`, else skipped) |

The library folder is the first of these that exists: the folder set in Output, then the USB stick
(`34870_G10_ListeningTest_2026-11-18/5_Vinyl`), then `~/Music/Vinyl`, then the home-server share.
Tracks are stored relative to that folder, so the USB stick and the server copy are interchangeable.
The check tones come from `../check_tones/` (or the stick's `3_Check_tones`).

## MiniDSP gains over USB (optional)

The panel can set the MiniDSP 2x4 HD's **output gains** by itself, so Part B no longer needs
someone at the MiniDSP plugin between samples. It uses **minidsp-rs**
(<https://github.com/mrene/minidsp-rs>, Apache-2.0), an open-source command-line program that talks
to the 2x4 HD over USB. The official miniDSP software is not needed and not touched.

**What it changes, and nothing else:** Output 1 (woofer) to −11.6, −5.8 or 0 dB, Output 2
(mid + tweeter) to 0 dB. Crossover filters, routing, PEQ, delay, invert, presets: never. Any
other value is refused by the panel before anything is sent.

**Requirements:** the 2x4 HD on **USB to the PC that runs the panel** (the panel is local,
`127.0.0.1`), so that PC sits by the listening room. The filters must already be loaded the usual
way (Setup checklist): minidsp-rs only changes gains.

### Install minidsp-rs (once per PC)

Shortcut: `bash minidsp/setup_minidsp.sh` (add `--udev` for the USB rule) does steps 1–3. By hand:


1. Download `minidsp.x86_64-unknown-linux-gnu.tar.gz` from
   <https://github.com/mrene/minidsp-rs/releases> (the README lists it under pre-built binaries).
2. Unpack it and put the `minidsp` program on the PATH, for example:
   ```
   tar xzf minidsp.x86_64-unknown-linux-gnu.tar.gz
   install -m 755 minidsp ~/.local/bin/
   minidsp --help        # should print the help text
   ```
   (Or build it: `cargo build --release --bin minidsp`, then copy `target/release/minidsp`.)
   Already done on the Desktop PC: v0.1.12 in `~/.local/bin/` (`minidsp` + `minidspd`).
3. **Permission to the USB device.** The rule (vendor 2752,
   incl. the 2x4 HD 2752:0011) at `~/.config/minidsp/99-minidsp.rules` (copy in this folder: `minidsp/99-minidsp.rules`). Install it once (needs sudo):
   ```
   sudo install -Dm644 minidsp/99-minidsp.rules /etc/udev/rules.d/99-minidsp.rules
   sudo udevadm control --reload-rules && sudo udevadm trigger
   ```
   Then unplug and replug the USB cable. Never run the panel itself with `sudo`.
4. Restart the panel. Output view → MiniDSP gains should say "minidsp CLI found".

### First hardware check (do this once, before the first real session)

Amplifier **off** (or volume fully down) for steps 1–5.

1. **Is the box seen?** USB cable in, MiniDSP powered: `lsusb | grep 2752` shows a line with
   ID `2752:0011`.
2. **Can minidsp-rs talk to it?** `minidsp probe` lists a 2x4HD. Then the read-only status:
   `minidsp --usb 2752:0011` (or `-o json`) prints the preset, source and master volume. Nothing
   is changed by these two.
3. **One safe gain set by hand**, the design values:
   ```
   minidsp --usb 2752:0011 output 0 gain -- -5.8
   minidsp --usb 2752:0011 output 1 gain -- 0
   ```
   The `--` is needed, or the program reads `-5.8` as an option. Both commands should finish
   silently with no error. If the official plugin is at hand on another PC, it can confirm the
   values; otherwise trust the exit status (minidsp-rs cannot read gains back).
4. **In the panel:** Output view → tick **Apply test gains automatically** → **Check connection**
   (read-only, should say "2x4 HD answered …") → **Set design now**. The status line should say
   "Last set: Out 1 −5.8 dB, Out 2 0 dB" with a green dot.
5. **Rehearse one step:** Steps view, session 1, go to a Part B sample whose level is not D, press
   Play: the step's note says "MiniDSP over USB: set to Out 1 …" and the music starts. Press Stop.
   Go to "After Part B": the panel puts the design back.
6. Amplifier on at a low level, play track 2 at L (−11.6) and at H (0 dB): the bass level should
   clearly change. Finish with **Set design now**.
7. **Load System D filters** (only if you want the panel to write the crossover instead of the
   official plugin; amp down first). It writes, per output, the two crossover biquads from
   `Project/Final design/data/dsp/MiniDSP_woofer_out1.txt` / `MiniDSP_midtw_out2.txt`, bypasses
   crossover group 2, PEQ, FIR and compressor, sets invert off, delay 0, unmute, routes Inputs 1+2 →
   Outputs 1+2 and ends at −5.8 / 0 dB (28 commands, about as many seconds at worst). The files are
   in the miniDSP sign convention (a1 ≈ +1.97); minidsp-rs sends coefficients to the box unchanged
   (checked in its source, `BiquadFilter::set_coefficients`), so they go in as they are.
   **Check it acoustically** before the session: woofer only (mid/tweeter off on the switchboard)
   should sound like a low-pass at 325 Hz, mid/tweeter only like the high-pass. Not covered by the
   button: the 96 kHz sample rate and saving a preset. If any command fails the box is partly
   loaded: do not play; press the button again or load the filters in the plugin.

If any step fails, untick the switch and run the test the old manual way (below).

#### Result on the real hardware (laptop, 27-Nov-2026, amplifier off)

Steps 1–3 run from the laptop with minidsp-rs 0.1.12. The udev rule was installed **before** the first
try, so whether the box also works without it is not known. With the rule the device node is
`crw-rw-rw-` (`/dev/bus/usb/003/004`), and every command ran without `sudo`.

```
$ lsusb | grep 2752
Bus 003 Device 004: ID 2752:0011 miniDSP miniDSP 2x4HD

$ minidsp probe
0: Found 2x4HD with serial 905335 at usb:3-2%3A1.4?vid=2752&pid=0011 [hw_id: 10, dsp_version: 100]

$ minidsp --usb 2752:0011
MasterStatus { preset: 0, source: Analog, volume: Gain(-0.0), mute: false, dirac: false }
Input levels: -59.6, -59.5
Output levels: -57.0, -100.9, -59.5, -101.2

$ minidsp --usb 2752:0011 output 0 gain -- -5.8     # exit 0, no output
$ minidsp --usb 2752:0011 output 1 gain -- 0        # exit 0, no output
```

**Timing:** setting both outputs (two CLI calls in a row) took **0.11–0.12 s** in three tries, so the
solo round's fixed 2.5 s lead (`SoloLink.LEAD`) has plenty of margin and was left unchanged.

Still open: whether the gains survive a MiniDSP power cycle. It does not matter for a session, because the
panel sends both gains before every sample and puts the design back between parts.

### How it runs during a session

- **Switch off (default):** nothing is sent; exactly the old manual way (set Out 1 by hand, then
  **✓ Set done** in Auto mode).
- **Switch on, Auto on:** at the end of each 40 s rating countdown the panel sets the next Part B
  level over USB and starts the sample. No **✓ Set done** for Out 1. Rp (Part C) and the vent
  (Part D) are still by hand and still wait for **✓ Set done** / the operator.
- **Switch on, Auto off:** pressing Play (or `P`) on a step first sets that step's gains, then plays.
- Every step that plays sends both gains first, even if nothing changed, so jumping back and forth
  between steps can never leave a wrong level. Part A and Part C send the design (−5.8 / 0).
- Steps without music (Before the session, After Part B, After Part C/D, Finish) put the design
  back when you open them, so Part C and the next session always start at −5.8 dB.
- **If a gain cannot be set** (CLI missing, USB unplugged, an error from minidsp), the panel shows
  the error in red and **does not play** the sample; auto-run stops. Fix it, or untick the switch
  and set Out 1 by hand. If Output 2's command fails, Output 1 may already have changed: the panel
  then treats both gains as unknown.
- `--test` (silent mode) never contacts the MiniDSP: the gains are only logged as "simulated", so
  rehearsals still run through the whole flow.

### MiniDSP troubleshooting

- **"minidsp CLI not found"**: `minidsp` is not on the PATH of the terminal that started the
  panel. Check with `which minidsp`, then restart the panel.
- **"no answer within 10 s" / "no device" errors**: USB cable, MiniDSP power, `lsusb | grep 2752`.
  Only one program can hold the box: close the official plugin on any other PC on the same USB,
  and do not run `minidspd` during a session (`pgrep -a minidspd`): the panel talks to the box
  directly over USB and does not need the daemon (its HTTP API on 127.0.0.1:5380 is optional).
- **Works only with sudo**: the udev rule above is missing or the cable was not replugged.
- **The plugin on another PC shows other values**: minidsp-rs writes to the box, but an already
  open plugin does not refresh. Its docs say the program cannot read settings back, so the panel
  shows what it last **sent**.

## Solo round (one listener, nobody outside)

For a test on your own: the PC, MiniDSP and amplifier stay outside, you sit inside with your phone,
and the phone drives the panel. Part A (optional) and Part B run; **Part C is not run solo** (Rp is
swapped by hand outside the room, which cannot be done blind alone).

1. Usual setup (Setup view), then Output view: **Apply test gains automatically** on, **Check
   connection**, **Set design now**. The solo round refuses to start without the MiniDSP switch on.
2. PC: no suspend or screen lock, charger in, internet on. Solo view → tick or untick *Include Part
   A* → **Start solo round**. A 4-digit code appears.
3. In the room, phone: **listening.madsrudolph.dev** → "Solo: my phone runs the PC" → the code. Each
   listening page starts its excerpt by itself; **Play again** repeats it, **Stop** ends it. Next
   works once the excerpt has finished or been stopped. The screen is kept awake while the round runs.
4. After sending, start another round for a second, independent order if you want more data.
5. **Tune by ear** (optional, after the rated parts, not blind): the form's last pages link to
   **listening.madsrudolph.dev/tune.html** (`?code=` filled in). Track 1–4 play buttons and Stop; Out 1
   (−18..0 dB) and Out 2 (−6..0 dB) with −1 / −0.5 / +0.5 / +1 buttons and a slider, 0.1 dB steps; "Back
   to the design" (−5.8 / 0). A change is sent 0.25 s after the last tap and is set **while the music
   plays**; the readout says "✓ set on the MiniDSP" once the panel confirms it. **Save as my pick** (with
   a note) stores the setting; picks show on the results page and in the CSV as part `tune`. The panel
   checks the range again (`MiniDSPControl.validate_manual`). After a blind Part B sample the phone is
   never told the level, and a tune play puts the design back first, so the tune page cannot reveal it.

How it works: the phone talks to the Worker (`web/src/worker.js`, Durable Object `SoloRoom`), and the
panel polls it every 0.7 s with the admin key from `../web/.admin-key`. When a round starts, the server
draws a random order of D, D, L, H. Only the panel process gets it: it never goes to the page or the
phone, and the panel shows only the sample names. Before **every** play the panel sets both outputs
over USB and waits until 2.5 s have passed since the tap, so a sample whose level did not change starts
exactly as late as one that did. An older tap that a newer one overtook is dropped and never sets a
gain. If the panel restarts mid-round it attaches to the open round again. The results page shows solo
listeners as `<n>S` with their decoded order (`solo DLHD` …); `times_played` rows in the CSV count replays.

Tests: `tests/test_solo.py` (no network, no hardware). `LISTENING_BASE=http://localhost:8787` points
the panel at a local `wrangler dev` instead of the live site.

## Troubleshooting

- **"Port 8771 is busy"**: the panel is already running; the browser opens it. Or start
  with `--port 8766`.
- **No sound:** check the sidebar output dot; Output view → "Panel output". "Follow the system
  default" uses whatever the system default is; pick the Modi there or in the system settings.
  The system volume and MiniDSP input level matter too.
- **"File not found"** on a track: the library folder is missing (USB stick not mounted, server
  out of reach). Plug in the stick or set the folder in Output, then Rescan.
- **A streaming row says "not running":** start the player (Spotify: **Open Spotify** in
  Players). Browser tabs only appear after they have played once.
- **"did not seek"** on a Spotify row: Spotify ignored the jump; that excerpt starts at 0:00. Try
  again, or use a local file for that track.
- The player restarts on its own if it crashes; the sidebar shows "Player restarting".
- Rehearse anything with `python3 control_panel.py --test` (silent).
