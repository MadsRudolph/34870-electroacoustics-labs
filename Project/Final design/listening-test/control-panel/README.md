# Listening-test control panel

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
- **Output:** which sound card is used, the library folder, the target loudness.

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

The library folder is the first of these that exists: the folder set in Output, then the USB stick
(`34870_G10_ListeningTest_2026-11-18/5_Vinyl`), then `~/Music/Vinyl`, then the home-server share.
Tracks are stored relative to that folder, so the USB stick and the server copy are interchangeable.
The check tones come from `../check_tones/` (or the stick's `3_Check_tones`).

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
