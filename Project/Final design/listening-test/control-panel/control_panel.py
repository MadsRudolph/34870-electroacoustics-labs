#!/usr/bin/env python3
"""Listening-test control panel (34870, Group 10, System D).

    python3 control_panel.py              # start, opens http://127.0.0.1:8771 in the browser
    python3 control_panel.py --test       # silent: mpv plays to a null output (nothing is heard)

One local web page controls:
  * the four test tracks (start, length, fades, loudness match to -23 LUFS, dual mono), from a local FLAC
    or from a streaming player (Spotify, Tidal, Qobuz in a browser ...) over MPRIS,
  * the procedure for each session of three listeners (Part A, B, C with the blind orders from the operator sheet),
  * the vinyl library (albums in order, pause, seek, next/previous),
  * other media players (play/pause/next) and the audio output.

Local files play through one mpv process controlled over its JSON IPC socket. Streaming players are
controlled over D-Bus (MPRIS) with `busctl`. Settings live in panel_settings.json next to this script.
Only the Python standard library is used, plus mpv, ffmpeg, busctl and pactl (and optionally the minidsp
CLI from minidsp-rs, which sets the MiniDSP 2x4 HD output gains over USB; see README).
"""
import argparse, ctypes, json, math, os, re, shutil, signal, socket, subprocess, sys, threading, time, urllib.error, urllib.request, webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

HERE = Path(__file__).resolve().parent
HTML_FILE = HERE / 'panel.html'

# Where the vinyl rips may be, in order of preference (the first that exists wins; a folder set in the
# page overrides this). The USB stick is local, so it is tried before the network share.
LIBRARY_CANDIDATES = [
    '/run/media/mads/USB DISK/34870_G10_ListeningTest_2026-11-18/5_Vinyl',
    str(Path.home() / 'Music/Vinyl'),
    '/mnt/homeserver/media/music/Vinyl',
]
# The three check tones for the electrical check (operator sheet): repo copy first, then the USB stick.
TONE_DIRS = [str(HERE.parent / 'check_tones'),
             '/run/media/mads/USB DISK/34870_G10_ListeningTest_2026-11-18/3_Check_tones']
TONES = {'100': 'tone_0100Hz_-12dBFS.wav', '325': 'tone_0325Hz_-12dBFS.wav', '1000': 'tone_1000Hz_-12dBFS.wav'}
AUDIO_EXT = ('.flac', '.wav', '.mp3', '.m4a', '.ogg', '.opus', '.aiff', '.aif')
MONO_PAN = 'pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1'      # left = right = (L+R)/2, as make_excerpts.py

# The four excerpts from make_excerpts.py (relative to the library folder). Length 90 s each.
DEFAULT_TRACKS = [
    dict(label='Female voice', source='Fugees/The Score (1996) [Vinyl]/1-03 - Ready or Not.flac', start=60),
    dict(label='Male voice', source='Michael Bublé/Christmas (2014) [Vinyl]/08 - Have Yourself a Merry Little Christmas.flac', start=25),
    dict(label='Bass', source='Miles Davis/Kind of Blue (1987) [Vinyl]/01 - So What.flac', start=32),
    dict(label='Full band', source='Electric Light Orchestra/Out of the Blue (1977) [Vinyl]/1-01 - Turn to Stone.flac', start=40),
]
for _t in DEFAULT_TRACKS:
    _t.update(kind='local', length=90.0, player='org.mpris.MediaPlayer2.spotify', uri='', title='', alts=[])
SONG_FIELDS = ('kind', 'source', 'player', 'uri', 'title', 'start', 'length')   # what an alternative song remembers

DEFAULT_SETTINGS = dict(
    tracks=DEFAULT_TRACKS, gap=2.0, target_lufs=-23.0, fade=0.5, library_dir='', audio_device='auto',
    listener=1, step=0, lib_mono=True, lib_match=True, lib_offset=0.0, part_d=False, minidsp_auto=False)

MPRIS_PREFIX = 'org.mpris.MediaPlayer2.'
MPRIS_PATH = '/org/mpris/MediaPlayer2'
PLAYER_IFACE = 'org.mpris.MediaPlayer2.Player'


def log(*a):
    print(time.strftime('%H:%M:%S'), *a, flush=True)


def _die_with_parent():
    """Run in the mpv child: ask Linux to stop mpv when the panel process dies (PR_SET_PDEATHSIG)."""
    try:
        ctypes.CDLL('libc.so.6').prctl(1, signal.SIGTERM)
    except Exception:
        pass


def fmt_time(s):
    s = max(0, int(round(s)))
    return f'{s // 60}:{s % 60:02d}'


def parse_time(v):
    """'1:30' or '90' or 90 -> 90.0 seconds."""
    if isinstance(v, (int, float)):
        return float(v)
    v = str(v).strip().replace(',', '.')
    if ':' in v:
        m, s = v.split(':', 1)
        return int(m or 0) * 60 + float(s or 0)
    return float(v)


def dir_ok(path, timeout=3.0):
    """isdir() with a timeout, because a dead network share can hang forever."""
    res = []
    th = threading.Thread(target=lambda: res.append(os.path.isdir(path)), daemon=True)
    th.start(); th.join(timeout)
    return bool(res and res[0])


def run(cmd, timeout=3.0):
    """Run a small command; return stdout, or None on any failure."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        return r.stdout if r.returncode == 0 else None
    except Exception:
        return None


def spotify_uri(text):
    """Normalise a Spotify link or URI to spotify:track:<id>; '' if it is not one."""
    m = re.search(r'(?:open\.spotify\.com/(?:intl-[a-z]+/)?track/|spotify:track:)([A-Za-z0-9]{22})', text or '')
    return f'spotify:track:{m.group(1)}' if m else ''


class MiniDSPError(RuntimeError):
    """A MiniDSP command could not be run or was refused. The message is shown to the operator."""


class MiniDSPControl:
    """Sets the two output gains of the MiniDSP 2x4 HD over USB with the open-source minidsp-rs CLI.

    set_gains() writes only the output gains: Output 1 (woofer) to one of the three listening-test
    levels, Output 2 (mid + tweeter) to 0 dB. load_filters() is a separate, explicit operator action
    that writes the System D crossover from data/dsp/MiniDSP_*.txt (the same files the operator
    pastes into the plugin's Xover -> Advanced page) plus the operator-sheet settings around it.
    In silent test mode (--test) nothing is sent: the commands are only logged and remembered as
    "simulated".
    minidsp-rs cannot read gains back from the device, so last_gains is what this panel last sent.
    """
    USB_ID = '2752:0011'                       # miniDSP vendor id : 2x4 HD product id
    OUTPUT1_GAINS = (-11.6, -5.8, 0.0)          # L, D (design), H
    OUTPUT2_GAIN = 0.0
    TIMEOUT = 10
    DSP_DIR = HERE.parent.parent / 'data' / 'dsp'
    FILTER_FILES = {0: 'MiniDSP_woofer_out1.txt', 1: 'MiniDSP_midtw_out2.txt'}   # output index -> file

    def __init__(self, null_audio=False, exe_name='minidsp'):
        self.null_audio = null_audio
        self.exe_name = exe_name
        self.lock = threading.Lock()
        self.last_gains = None      # dict(output1, output2) once a full set succeeded, None = unknown
        self.last_error = ''
        self.last_check = ''
        self.simulated = False
        self.last_filters = ''      # short description once a full filter load succeeded

    def exe(self):
        return shutil.which(self.exe_name)

    def status(self, enabled):
        return dict(enabled=bool(enabled), available=self.exe() is not None, null_audio=self.null_audio,
                    last_gains=self.last_gains, simulated=self.simulated, last_error=self.last_error,
                    check=self.last_check, filters=self.last_filters, busy=self.lock.locked())

    @classmethod
    def validate(cls, output1, output2):
        """Return (output1, output2) as floats, or raise ValueError for anything but the test levels."""
        try:
            g1, g2 = float(output1), float(output2)
        except (TypeError, ValueError):
            raise ValueError('MiniDSP gains must be numbers')
        if not (math.isfinite(g1) and math.isfinite(g2)):
            raise ValueError('MiniDSP gains must be finite numbers')
        match = [g for g in cls.OUTPUT1_GAINS if abs(g1 - g) < 1e-6]
        if not match or abs(g2 - cls.OUTPUT2_GAIN) > 1e-6:
            raise ValueError('Refused: the listening test only uses Output 1 at -11.6, -5.8 or 0 dB '
                             f'and Output 2 at 0 dB (got {g1:g} / {g2:g} dB)')
        return match[0], cls.OUTPUT2_GAIN

    MANUAL_RANGE = ((-18.0, 0.0), (-6.0, 0.0))  # by-hand tuning from the phone: Out 1, Out 2, 0.5 dB steps

    @classmethod
    def validate_manual(cls, output1, output2):
        """Gains set by hand (solo tune page): Out 1 -18..0, Out 2 -6..0 dB in 0.5 dB steps. Never above 0 dB."""
        try:
            g = [float(output1), float(output2)]
        except (TypeError, ValueError):
            raise ValueError('MiniDSP gains must be numbers')
        for v, (lo, hi), name in zip(g, cls.MANUAL_RANGE, ('Output 1', 'Output 2')):
            if not math.isfinite(v) or v < lo - 1e-9 or v > hi + 1e-9 or abs(v * 2 - round(v * 2)) > 1e-6:
                raise ValueError(f'Refused: {name} by hand must be {lo:g}..{hi:g} dB in 0.5 dB steps (got {v:g})')
        return round(g[0] * 2) / 2, round(g[1] * 2) / 2

    def set_manual(self, output1, output2):
        """Set both gains to hand-picked values (validated against MANUAL_RANGE, not the three test levels)."""
        g1, g2 = self.validate_manual(output1, output2)
        return self._send(g1, g2)

    def gain_command(self, exe, index, gain):
        # `--` before the value, or the CLI reads a negative gain such as -5.8 as an option.
        return [exe, '--usb', self.USB_ID, 'output', str(index), 'gain', '--', f'{gain:g}']

    def _run(self, cmd, what):
        try:
            r = subprocess.run(cmd, capture_output=True, text=True, timeout=self.TIMEOUT)
        except subprocess.TimeoutExpired:
            raise MiniDSPError(f'{what}: no answer within {self.TIMEOUT} s (is the 2x4 HD connected over USB?)')
        except OSError as e:
            raise MiniDSPError(f'{what}: could not run minidsp ({e})')
        if r.returncode != 0:
            detail = (r.stderr or r.stdout or '').strip().splitlines()
            detail = detail[-1] if detail else f'exit code {r.returncode}'
            if 'No devices found' in detail:
                detail += ' (the 2x4 HD is not on USB: cable, power, `lsusb | grep 2752`)'
            raise MiniDSPError(f'{what} failed: {detail}')
        return r.stdout

    def set_gains(self, output1, output2):
        """Set Output 1 then Output 2. Raises MiniDSPError/ValueError; on any failure the gains are unknown."""
        g1, g2 = self.validate(output1, output2)
        return self._send(g1, g2)

    def _send(self, g1, g2):
        if self.null_audio:
            with self.lock:
                log(f'MiniDSP (simulated, --test): Out 1 {g1:g} dB, Out 2 {g2:g} dB')
                self.last_gains, self.simulated, self.last_error = dict(output1=g1, output2=g2), True, ''
            return self.last_gains
        exe = self.exe()
        if not exe:
            self.last_error = 'minidsp CLI not found: install minidsp-rs (see README) and restart the panel'
            raise MiniDSPError(self.last_error)
        with self.lock:
            self.last_gains, self.simulated = None, False         # unknown until both commands succeed
            try:
                for index, gain in ((0, g1), (1, g2)):
                    self._run(self.gain_command(exe, index, gain), f'MiniDSP Output {index + 1} gain {gain:g} dB')
            except MiniDSPError as e:
                self.last_error = str(e) + ('' if 'Output 1' in str(e) else ' (Output 1 may already have changed)')
                log(self.last_error)
                raise MiniDSPError(self.last_error) from None
            self.last_gains, self.last_error = dict(output1=g1, output2=g2), ''
            log(f'MiniDSP set: Out 1 {g1:g} dB, Out 2 {g2:g} dB')
            return self.last_gains

    @staticmethod
    def parse_filter_file(path):
        """Read a miniDSP 'Advanced' biquad file (biquad1, b0 = ..., ...). Returns [(b0, b1, b2, a1, a2), ...].

        The coefficients are in the miniDSP sign convention (a1, a2 as the plugin wants them);
        minidsp-rs passes them to the device unchanged, so they are not altered here."""
        text = Path(path).read_text(encoding='utf-8')
        out, cur = [], None
        for raw in text.replace(',', '\n').splitlines():
            line = raw.strip()
            if not line:
                continue
            if re.fullmatch(r'biquad\d+', line):
                cur = {}
                out.append(cur)
                continue
            m = re.fullmatch(r'(b0|b1|b2|a1|a2)\s*=\s*(\S+)', line)
            if not m or cur is None or m.group(1) in cur:
                raise ValueError(f'{Path(path).name}: unexpected line "{line}"')
            v = float(m.group(2))
            if not math.isfinite(v):
                raise ValueError(f'{Path(path).name}: {m.group(1)} is not a finite number')
            cur[m.group(1)] = v
        bqs = []
        for i, c in enumerate(out):
            if sorted(c) != ['a1', 'a2', 'b0', 'b1', 'b2']:
                raise ValueError(f'{Path(path).name}: biquad {i + 1} is incomplete')
            bqs.append(tuple(c[k] for k in ('b0', 'b1', 'b2', 'a1', 'a2')))
        if len(bqs) != 2:                     # System D: exactly two biquads per output (an LR4 / 2x BW2)
            raise ValueError(f'{Path(path).name}: expected exactly 2 biquads, found {len(bqs)}')
        for i, (b0, b1, b2, a1, a2) in enumerate(bqs):     # stable: poles of z^2 - a1 z - a2 inside the unit circle
            if not (abs(a2) < 1 and abs(a1) < 1 - a2):
                raise ValueError(f'{Path(path).name}: biquad {i + 1} would be unstable in the miniDSP convention')
        return bqs

    def filter_commands(self, exe, design=(-5.8, 0.0)):
        """Every CLI call for a full System D load, in order (see ListeningTest_Operator.tex, Set up)."""
        base = [exe, '--usb', self.USB_ID]
        cmds = []
        for o, name in self.FILTER_FILES.items():
            bqs = self.parse_filter_file(self.DSP_DIR / name)
            tag = f'Output {o + 1}'
            cmds.append((base + ['output', str(o), 'crossover', 'all', 'all', 'clear'], f'{tag}: clear crossover'))
            for i, bq in enumerate(bqs):
                cmds.append((base + ['output', str(o), 'crossover', '0', str(i), 'set', '--'] + [repr(float(c)) for c in bq],
                             f'{tag}: crossover biquad {i + 1} from {name}'))
            cmds += [
                (base + ['output', str(o), 'crossover', '0', 'all', 'bypass', 'off'], f'{tag}: crossover group 1 on'),
                (base + ['output', str(o), 'crossover', '1', 'all', 'bypass', 'on'], f'{tag}: crossover group 2 bypassed'),
                (base + ['output', str(o), 'peq', 'all', 'bypass', 'on'], f'{tag}: PEQ bypassed'),
                (base + ['output', str(o), 'fir', 'bypass', 'on'], f'{tag}: FIR bypassed'),
                (base + ['output', str(o), 'compressor', '--bypass', 'on'], f'{tag}: compressor bypassed'),
                (base + ['output', str(o), 'invert', 'off'], f'{tag}: invert off'),
                (base + ['output', str(o), 'delay', '0'], f'{tag}: delay 0'),
                (base + ['output', str(o), 'mute', 'off'], f'{tag}: unmute'),
            ]
        for i in (0, 1):                      # Input 1 and Input 2 -> Output 1 and Output 2 (Spotify is stereo)
            for o in (0, 1):
                cmds.append((base + ['input', str(i), 'routing', str(o), 'enable', 'on'],
                             f'routing Input {i + 1} -> Output {o + 1}'))
        for o, g in enumerate(design):
            cmds.append((self.gain_command(exe, o, g), f'Output {o + 1} gain {g:g} dB'))
        return cmds

    def load_filters(self):
        """Write the System D crossover and the operator-sheet settings, ending at the design gains.

        Raises ValueError (bad filter file, nothing sent) or MiniDSPError (device/CLI; the box is then
        in an unknown, partly loaded state)."""
        if self.null_audio:
            cmds = self.filter_commands('minidsp')     # still parses and checks the files
            with self.lock:
                for _, what in cmds:
                    log(f'MiniDSP (simulated, --test): {what}')
                self.last_gains, self.simulated, self.last_error = dict(output1=-5.8, output2=0.0), True, ''
                self.last_filters = 'System D filters loaded (simulated)' + time.strftime(' %H:%M:%S')
            return dict(steps=len(cmds), simulated=True)
        exe = self.exe()
        if not exe:
            self.last_error = 'minidsp CLI not found: install minidsp-rs (see README) and restart the panel'
            raise MiniDSPError(self.last_error)
        cmds = self.filter_commands(exe)               # ValueError here: nothing has been sent
        with self.lock:
            self.last_gains, self.simulated, self.last_filters = None, False, ''
            for n, (cmd, what) in enumerate(cmds, 1):
                try:
                    self._run(cmd, f'MiniDSP {what}')
                except MiniDSPError as e:
                    self.last_error = f'{e} (step {n} of {len(cmds)}: the MiniDSP is only partly loaded, do not play)'
                    log(self.last_error)
                    raise MiniDSPError(self.last_error) from None
            self.last_gains, self.last_error = dict(output1=-5.8, output2=0.0), ''
            self.last_filters = f'System D filters loaded ({len(cmds)} commands)' + time.strftime(' %H:%M:%S')
            log(self.last_filters)
        return dict(steps=len(cmds), simulated=False)

    def check(self):
        """Read-only: ask the 2x4 HD for its status summary. Returns a short message or raises."""
        if self.null_audio:
            self.last_check = 'skipped in silent test mode'
            return 'Silent test mode: the MiniDSP is not contacted.'
        exe = self.exe()
        if not exe:
            self.last_check = 'minidsp CLI not found'
            raise MiniDSPError('minidsp CLI not found: install minidsp-rs (see README) and restart the panel')
        with self.lock:
            try:
                out = self._run([exe, '--usb', self.USB_ID, '-o', 'json'], 'MiniDSP status read')
            except MiniDSPError as e:
                self.last_check = str(e)
                raise
        try:
            m = json.loads(out.strip().splitlines()[-1]).get('master', {})
            msg = f"2x4 HD answered: preset {m.get('preset', '?')}, master volume {m.get('volume', '?')}, mute {m.get('mute', '?')}"
        except (ValueError, IndexError, AttributeError):
            msg = '2x4 HD answered: ' + (out.strip().splitlines() or ['(no output)'])[0][:120]
        self.last_check = msg + time.strftime(' (%H:%M:%S)')
        return msg


# ----------------------------------------------------------------------------------------------------
# Settings and loudness cache (JSON files next to the script)
# ----------------------------------------------------------------------------------------------------
class SoloLink:
    """A solo round: one listener in the room drives this panel from the phone form.

    The phone talks to listening.madsrudolph.dev (a Durable Object, /api/solo/*); this class polls it about
    every 0.7 s with the admin key, reports what plays, and carries out the phone's commands: "play A1..A4"
    (the design) or "play B1..B4" (Out 1 from the round's random order, which the server drew and only this
    process knows), and "stop". Before every play it sets BOTH MiniDSP gains and then waits until a fixed
    time has passed, so a sample whose setting did not change starts exactly as late as one that did.
    The order is never sent to the page; the results page decodes it after the round.
    """
    BASE = 'https://listening.madsrudolph.dev'
    KEY_FILE = HERE.parent / 'web' / '.admin-key'
    POLL = 0.7
    LEAD = 2.5                  # seconds from the phone's tap to the voice cue, the same for every sample
    GAIN = {'L': -11.6, 'D': -5.8, 'H': 0.0}

    def __init__(self, panel, base=None):
        self.panel = panel
        self.base = base or os.environ.get('LISTENING_BASE', self.BASE)
        self.lock = threading.Lock()
        self.round = None                       # the server's round, incl. 'order' (never sent to the page)
        self.handled = 0                        # last command seq carried out
        self.state = dict(seq=0, state='idle', item=None, msg='')
        self.error = ''
        self.phone_age = None
        self.last_ok = 0.0
        self.history = []                       # [{item, t, state}] without conditions, for the operator
        self.thread = None
        self.stop_evt = threading.Event()
        self.do_lock = threading.Lock()         # one command at a time: an old tap can never set a gain late
        self.gain = None                        # what the phone may see: {out1, out2, source: manual|design}, None = hidden/unknown

    def key(self):
        try:
            return self.KEY_FILE.read_text().strip()
        except OSError:
            return ''

    def _req(self, path, body=None, timeout=6):
        k = self.key()
        if not k:
            raise RuntimeError(f'admin key missing ({self.KEY_FILE})')
        data = json.dumps(body or {}).encode()
        req = urllib.request.Request(f'{self.base}{path}?key={k}', data=data, method='POST',
                                     headers={'content-type': 'application/json', 'user-agent': 'listening-panel'})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return json.loads(r.read() or b'{}')
        except urllib.error.HTTPError as e:
            raise RuntimeError(f'server answered {e.code}') from None
        except (urllib.error.URLError, TimeoutError, OSError) as e:
            raise RuntimeError(f'no connection to {self.base} ({getattr(e, "reason", e)})') from None

    # ---------- operator actions ----------
    def ready_problem(self):
        p = self.panel
        if p.null_audio:
            return ''
        if not p.s.get('minidsp_auto', False):
            return 'Turn on "Apply test gains automatically" (Output view) first: the solo round sets Out 1 over USB.'
        if not p.minidsp.exe():
            return 'minidsp CLI not found (see README).'
        return ''

    def start(self, part_a=True):
        prob = self.ready_problem()
        if prob:
            raise RuntimeError(prob)
        j = self._req('/api/solo/new', {'partA': bool(part_a)})
        with self.lock:
            self.round, self.handled = j['round'], j['cmd'].get('seq', 0)
            self.state = dict(seq=self.handled, state='idle', item=None, msg='')
            self.history, self.error, self.phone_age = [], '', None
        log(f'Solo round {self.round["n"]} started (code {self.round["code"]}, Part A {"on" if part_a else "off"})')
        self._design()
        self._ensure_thread()
        return self.round

    def end(self):
        try:
            self._req('/api/solo/end')
        except RuntimeError as e:
            log('solo end:', e)
        with self.lock:
            r, self.round = self.round, None
        if r:
            log(f'Solo round {r["n"]} ended')
        self.panel.stop()
        self._design()

    def resume(self):
        """At start-up: re-attach to a round that is still open on the server (panel restarted mid-round)."""
        try:
            j = self._req('/api/solo/panel', {'state': self.state})
        except RuntimeError:
            return
        r = j.get('round')
        if r and not r.get('ended'):
            with self.lock:
                self.round, self.handled = r, j['cmd'].get('seq', 0)    # never replay an old tap
                self.state['seq'] = self.handled
            log(f'Solo round {r["n"]} is still open: re-attached (code {r["code"]})')
            self._ensure_thread()

    def _design(self):
        if self.panel.s.get('minidsp_auto', False) or self.panel.null_audio:
            try:
                self.panel.minidsp.set_gains(-5.8, 0.0)
            except (MiniDSPError, ValueError) as e:
                log('solo: design gains not set:', e)

    def status(self):
        with self.lock:
            r = self.round
            return dict(active=bool(r), n=r and r['n'], code=r and r['code'], partA=r and r['partA'],
                        state=dict(self.state), error=self.error, phone_age=self.phone_age,
                        online=time.monotonic() - self.last_ok < 5, history=list(self.history[-20:]),
                        problem=self.ready_problem(), key=bool(self.key()))

    # ---------- the loop ----------
    def _ensure_thread(self):
        if self.thread and self.thread.is_alive():
            return
        self.thread = threading.Thread(target=self._loop, daemon=True)
        self.thread.start()

    def _loop(self):
        while not self.stop_evt.is_set():
            with self.lock:
                active = self.round is not None
            if not active:
                return
            self._watch()
            try:
                with self.lock:
                    st = dict(self.state)
                j = self._req('/api/solo/panel', {'state': st})
                with self.lock:
                    self.error, self.last_ok, self.phone_age = '', time.monotonic(), j.get('phone_age')
                    r = j.get('round')
                    if not r or r.get('ended') or (self.round and r['id'] != self.round['id']):
                        log('Solo round closed on the server')
                        self.round = None
                        return
                    cmd = j.get('cmd') or {}
                    new = cmd.get('seq', 0) > self.handled
                    if new:
                        self.handled = cmd['seq']
                if new:
                    threading.Thread(target=self._do, args=(cmd,), daemon=True).start()
            except RuntimeError as e:
                with self.lock:
                    self.error = str(e)
            self.stop_evt.wait(self.POLL)

    def _set_state(self, seq, state, item=None, msg='', **extra):
        with self.lock:
            if seq < self.state.get('seq', 0):
                return                               # a newer command took over
            self.state = dict(seq=seq, state=state, item=item, msg=msg, gain=self.gain, **extra)
            if state in ('playing', 'done', 'stopped', 'error') and item:
                h = self.history
                if h and h[-1]['seq'] == seq:
                    h[-1].update(state=state)
                else:
                    h.append(dict(seq=seq, item=item, t=time.strftime('%H:%M:%S'), state=state))

    def plan(self, item):
        """item -> (tracks, cue, Out 1 gain). Raises ValueError for anything else."""
        if not re.fullmatch(r'[ABT][1-4]', str(item or '')):
            raise ValueError(f'unknown item {item!r}')
        k = int(item[1])
        if item[0] == 'T':                                  # tune page: any track, the gains stay as they are
            return [k - 1], None, None
        if item[0] == 'A':
            if not self.round.get('partA', True):
                raise ValueError('Part A is off in this round')
            return [k - 1], f'a{k}', self.GAIN['D']
        return [1, 2], f'b{k}', self.GAIN[self.round['order'][k - 1]]

    def _do(self, cmd):
        with self.do_lock:
            with self.lock:
                if cmd['seq'] != self.handled:
                    return                               # superseded by a newer tap before it started
            self._do_one(cmd)

    def _do_one(self, cmd):
        seq, action, item = cmd['seq'], cmd.get('action'), cmd.get('item')
        p = self.panel
        if action == 'stop':
            p.stop()
            with self.lock:
                cur = dict(self.state)
            self._set_state(seq, 'stopped', cur.get('item') or item)
            return
        if action == 'gain':
            return self._gain(cmd)
        if action != 'play':
            return
        t0 = time.monotonic()
        try:
            with self.lock:
                tracks, cue, g1 = self.plan(item)
            if g1 is None:
                return self._play_tune(seq, item, tracks)
        except ValueError as e:
            self._set_state(seq, 'error', item, str(e))
            return
        self._set_state(seq, 'setting', item)
        p.stop()                                         # never set a gain while something plays
        try:
            p.minidsp.set_gains(g1, 0.0)                 # always both outputs: same timing for every sample
        except (MiniDSPError, ValueError) as e:
            self.gain = None
            self._set_state(seq, 'error', item, 'the MiniDSP could not be set (' + str(e)[:160] + ')')
            return
        # Part A is the design and may be shown; a Part B level never reaches the phone.
        self.gain = dict(out1=-5.8, out2=0.0, source='design') if item[0] == 'A' else None
        left = self.LEAD - (time.monotonic() - t0)
        if left > 0:
            time.sleep(left)
        else:
            log(f'solo: setting the MiniDSP took {self.LEAD - left:.1f} s, more than the fixed {self.LEAD} s lead')
        with self.lock:
            if self.handled != seq or self.round is None:
                return                                    # a newer tap arrived meanwhile
        label = f'Solo · {item}'
        use_cue = p.s.get('cues', True) is not False
        p.play_tracks(tracks, label=label, cue=cue if use_cue else None)
        self._set_state(seq, 'playing', item, label=label, started=time.monotonic())

    def _gain(self, cmd):
        """Set by hand from the tune page, also while music plays (no stop: that is the point of tuning by ear)."""
        seq = cmd['seq']
        with self.lock:
            prev = dict(self.state)
        try:
            g1, g2 = self.panel.minidsp.set_manual(cmd.get('out1'), cmd.get('out2'))
        except (MiniDSPError, ValueError) as e:
            self.gain = None
            self._set_state(seq, 'error', 'gain', 'the MiniDSP could not be set (' + str(e)[:160] + ')')
            return
        self.gain = dict(out1=g1, out2=g2, source='manual')
        log(f'Solo: gains set by hand from the phone: Out 1 {g1:g} dB, Out 2 {g2:g} dB')
        with self.lock:
            self.history.append(dict(seq=seq, item=f'by hand: Out 1 {g1:g} / Out 2 {g2:g} dB', t=time.strftime('%H:%M:%S'), state='set'))
        if prev.get('state') == 'playing':               # keep reporting the music that is still playing
            keep = {k: prev[k] for k in ('label', 'started', 'track', 'elapsed', 'length') if k in prev}
            self._set_state(seq, 'playing', prev.get('item'), **keep)
        else:
            self._set_state(seq, 'gain_set', 'gain')

    def _play_tune(self, seq, item, tracks):
        """Tune page: play one track at the gains that are set now. After a blind sample (gain unknown to the
        phone) the design goes back first, so a tune play never runs at a hidden Part B level."""
        p = self.panel
        self._set_state(seq, 'setting', item)
        p.stop()
        if self.gain is None:
            try:
                p.minidsp.set_gains(-5.8, 0.0)
            except (MiniDSPError, ValueError) as e:
                self._set_state(seq, 'error', item, 'the MiniDSP could not be set (' + str(e)[:160] + ')')
                return
            self.gain = dict(out1=-5.8, out2=0.0, source='design')
        with self.lock:
            if self.handled != seq or self.round is None:
                return
        label = f'Solo · {item}'
        p.play_tracks(tracks, label=label)
        self._set_state(seq, 'playing', item, label=label, started=time.monotonic())

    def _watch(self):
        """Turn the panel's playback into the state the phone sees (playing, done, stopped, error)."""
        with self.lock:
            st = dict(self.state)
        if st.get('state') != 'playing':
            return
        p = self.panel
        with p.lock:
            chain, mode, finished, msg = p.chain, p.mode, p.finished_at, p.message
        ours = chain is not None and chain.get('name') == st.get('label')
        extra = {k: st[k] for k in ('label', 'started') if k in st}
        if ours:
            n = p.status()['now']
            track = None
            if n.get('track') is not None:
                track = int(n['track']) + 1
            self._set_state(st['seq'], 'playing', st['item'], track=track,
                            elapsed=round(n.get('elapsed') or 0, 1), length=round(n.get('length') or 0, 1), **extra)
        elif time.monotonic() - st.get('started', 0) < 1.0:
            return                                        # the play thread has not set the chain yet
        elif mode is None and msg:
            self._set_state(st['seq'], 'error', st['item'], msg[:200])
        elif mode is None and finished and finished >= st.get('started', 0):
            self._set_state(st['seq'], 'done', st['item'])
        else:
            self._set_state(st['seq'], 'stopped', st['item'])

    def close(self):
        self.stop_evt.set()


class Store:
    def __init__(self, settings_path, cache_path):
        self.path, self.cache_path = Path(settings_path), Path(cache_path)
        self.lock = threading.RLock()
        self.s = json.loads(json.dumps(DEFAULT_SETTINGS))
        try:
            saved = json.loads(self.path.read_text())
            for k in self.s:
                if k in saved:
                    self.s[k] = saved[k]
            for i, t in enumerate(self.s['tracks'][:4]):      # fill fields that older files lack
                for k, v in DEFAULT_TRACKS[i].items():
                    t.setdefault(k, json.loads(json.dumps(v)))     # a copy: never share the default lists
            self.s['tracks'] = (self.s['tracks'] + json.loads(json.dumps(DEFAULT_TRACKS)))[:4]
            log('settings loaded from', self.path)
        except FileNotFoundError:
            log('no settings file yet, using the defaults')
        except Exception as e:
            log('settings file unreadable, using the defaults:', e)
        try:
            self.cache = json.loads(self.cache_path.read_text())
        except Exception:
            self.cache = {}

    def save(self):
        with self.lock:
            tmp = self.path.with_suffix('.tmp')
            tmp.write_text(json.dumps(self.s, indent=2, ensure_ascii=False) + '\n')
            tmp.replace(self.path)

    def save_cache(self):
        with self.lock:
            tmp = self.cache_path.with_suffix('.tmp')
            tmp.write_text(json.dumps(self.cache, indent=1, ensure_ascii=False) + '\n')
            tmp.replace(self.cache_path)


# ----------------------------------------------------------------------------------------------------
# Loudness: integrated loudness (EBU R128) of exactly what will be played, measured with ffmpeg, cached
# ----------------------------------------------------------------------------------------------------
class Loudness:
    def __init__(self, store):
        self.store = store
        self.busy = {}                     # key -> Lock, so one key is measured only once at a time
        self.errors = {}
        self.lock = threading.Lock()

    @staticmethod
    def key(rel, start, length, mono, fade):
        return f'{rel}|{start:g}|{length:g}|{"mono" if mono else "stereo"}|{fade:g}'

    def cached(self, key):
        return self.store.cache.get(key)

    def measure(self, path, rel, start=None, length=None, mono=True, fade=0.0):
        """Return {'lufs', 'peak'} (peak = true peak in dBTP before gain) or None. start/length None = whole file."""
        key = self.key(rel, start or 0, length or 0, mono, fade if length else 0)
        hit = self.cached(key)
        if hit:
            return hit
        with self.lock:
            lk = self.busy.setdefault(key, threading.Lock())
        with lk:
            hit = self.cached(key)
            if hit:
                return hit
            chain = []
            if mono:
                chain.append('aformat=channel_layouts=stereo,' + MONO_PAN)
            if length and fade:
                chain.append(f'afade=t=in:d={fade},afade=t=out:st={length - fade}:d={fade}')
            chain.append('ebur128=peak=true')
            cmd = ['ffmpeg', '-hide_banner', '-nostats', '-vn']
            if start:
                cmd += ['-ss', str(start)]
            if length:
                cmd += ['-t', str(length)]
            cmd += ['-i', str(path), '-af', ','.join(chain), '-f', 'null', '-']
            try:
                err = subprocess.run(cmd, capture_output=True, text=True, timeout=120).stderr
                summ = err[err.rfind('Summary:'):]
                lufs = float(re.search(r'I:\s+(-?[\d.]+) LUFS', summ).group(1))
                pk = re.search(r'Peak:\s+(-?[\d.]+|-inf) dBFS', summ).group(1)
                res = {'lufs': lufs, 'peak': -99.0 if pk == '-inf' else float(pk)}
            except Exception as e:
                self.errors[key] = str(e)[:200]
                log('loudness measurement failed for', rel, e)
                return None
            self.store.cache[key] = res
            self.store.save_cache()
            log(f'loudness {rel} start {start} len {length}: {res["lufs"]:.1f} LUFS, peak {res["peak"]:.1f} dBTP')
            return res


# ----------------------------------------------------------------------------------------------------
# mpv: one long-running process, JSON IPC over a Unix socket. Restarted automatically if it dies.
# ----------------------------------------------------------------------------------------------------
class Mpv:
    OBSERVE = ['time-pos', 'pause', 'path', 'duration', 'playlist-pos', 'playlist-count', 'idle-active',
               'media-title', 'audio-device', 'volume-gain']

    def __init__(self, null_audio, device, on_event):
        self.null_audio, self.device, self.on_event = null_audio, device, on_event
        self.sock_path = f'{os.environ.get("XDG_RUNTIME_DIR", "/tmp")}/listening-panel-mpv-{os.getpid()}.sock'
        self.proc = self.sock = None
        self.send_lock = threading.Lock()
        self.rid = 0
        self.replies, self.reply_cv = {}, threading.Condition()
        self.props = {}
        self.ended, self.ended_cv = {}, threading.Condition()   # playlist_entry_id -> end reason
        self.alive = False
        self.closing = False
        self.start()

    def start(self):
        if os.path.exists(self.sock_path):
            os.remove(self.sock_path)
        args = ['mpv', '--no-config', '--load-scripts=no', '--idle=yes', '--no-video', '--no-terminal',
                '--force-window=no', f'--input-ipc-server={self.sock_path}', '--volume=100', '--volume-max=100',
                '--replaygain=no', '--cache=yes', '--demuxer-max-bytes=400MiB', '--demuxer-readahead-secs=900',
                '--keep-open=no', '--audio-display=no', '--audio-pitch-correction=no']
        args.append('--ao=null' if self.null_audio else f'--audio-device={self.device or "auto"}')
        self.proc = subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     preexec_fn=_die_with_parent)
        for _ in range(100):
            if os.path.exists(self.sock_path):
                try:
                    s = socket.socket(socket.AF_UNIX)
                    s.connect(self.sock_path)
                    self.sock = s
                    break
                except OSError:
                    pass
            time.sleep(0.05)
        else:
            raise RuntimeError('mpv did not start (is mpv installed?)')
        self.alive = True
        threading.Thread(target=self._reader, daemon=True).start()
        for i, p in enumerate(self.OBSERVE):
            self.cmd(['observe_property', i + 1, p])
        log('mpv started, pid', self.proc.pid, '(null audio)' if self.null_audio else '')

    def _reader(self):
        f = self.sock.makefile('rb')
        for line in f:
            try:
                m = json.loads(line)
            except ValueError:
                continue
            if 'request_id' in m and 'event' not in m:
                with self.reply_cv:
                    self.replies[m['request_id']] = m
                    self.reply_cv.notify_all()
                continue
            ev = m.get('event')
            if ev == 'property-change':
                self.props[m['name']] = m.get('data')
            elif ev == 'end-file':
                with self.ended_cv:
                    self.ended[m.get('playlist_entry_id')] = m.get('reason')
                    self.ended_cv.notify_all()
            if ev:
                try:
                    self.on_event(m)
                except Exception as e:
                    log('event handler error:', e)
        # socket closed: mpv quit or crashed
        self.alive = False
        with self.ended_cv:
            self.ended_cv.notify_all()
        if not self.closing:
            log('mpv stopped unexpectedly, restarting it')
            time.sleep(1)
            try:
                self.props = {}
                self.start()
            except Exception as e:
                log('could not restart mpv:', e)

    def cmd(self, command, timeout=3.0):
        """Send a command and wait for its reply. Returns the reply dict ({'error': ...} on failure)."""
        if not self.alive:
            return {'error': 'mpv not running'}
        with self.send_lock:
            self.rid += 1
            rid = self.rid
            try:
                self.sock.sendall((json.dumps({'command': command, 'request_id': rid}) + '\n').encode())
            except OSError as e:
                return {'error': str(e)}
        end = time.time() + timeout
        with self.reply_cv:
            while rid not in self.replies:
                left = end - time.time()
                if left <= 0:
                    return {'error': 'timeout'}
                self.reply_cv.wait(left)
            return self.replies.pop(rid)

    def set(self, prop, value):
        return self.cmd(['set_property', prop, value])

    def get(self, prop):
        return self.cmd(['get_property', prop]).get('data')

    def wait_end(self, entry_id, cancel):
        """Block until mpv finishes playlist entry `entry_id` (returns the reason) or `cancel` is set (None)."""
        with self.ended_cv:
            while entry_id not in self.ended:
                if cancel.is_set():
                    return None
                if not self.alive:
                    return 'error'
                self.ended_cv.wait(0.1)
            return self.ended.pop(entry_id)

    def fade_stop(self, dur=0.25):
        """Fade the mpv volume down quickly, stop, put the volume back to 100 (avoids a click)."""
        if self.alive and not self.props.get('idle-active') and not self.props.get('pause'):
            for i in range(10, -1, -1):
                self.set('volume', i * 10)
                time.sleep(dur / 10)
        self.cmd(['stop'])
        self.set('volume', 100)

    def close(self):
        self.closing = True
        try:
            self.cmd(['quit'], timeout=1)
            self.proc.wait(2)
        except Exception:
            self.proc.kill()
        if os.path.exists(self.sock_path):
            os.remove(self.sock_path)


# ----------------------------------------------------------------------------------------------------
# MPRIS over busctl (Spotify, browsers, tidal-hifi ...)
# ----------------------------------------------------------------------------------------------------
def _unwrap(v):
    """busctl --json=short wraps every variant as {'type':..., 'data':...}; strip that recursively."""
    if isinstance(v, dict) and set(v) == {'type', 'data'}:
        return _unwrap(v['data'])
    if isinstance(v, dict):
        return {k: _unwrap(x) for k, x in v.items()}
    if isinstance(v, list):
        return [_unwrap(x) for x in v]
    return v


class Mpris:
    @staticmethod
    def busctl(*args, timeout=2.0):
        out = run(['busctl', '--user', '--json=short', '--', *args], timeout)
        if out is None:
            return None
        out = out.strip()
        return json.loads(out) if out else {}

    def names(self, local_only=False):
        r = self.busctl('call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ListNames')
        if not r:
            return []
        names = sorted(n for n in r['data'][0] if n.startswith(MPRIS_PREFIX))
        return [n for n in names if not self.is_remote(n)] if local_only else names

    def is_remote(self, name, identity=None):
        """A player on another device, mirrored here by KDE Connect ("Spotify - Desktop"). Never control it:
        with Spotify Connect, pausing the desktop's Spotify pauses the account, i.e. the song playing here."""
        if 'kdeconnect' in name.lower():
            return True
        if identity is None:
            identity = (self.props(name, 'org.mpris.MediaPlayer2') or {}).get('Identity', '')
        return str(identity).endswith(' - Desktop')

    def props(self, name, iface=PLAYER_IFACE):
        r = self.busctl('call', name, MPRIS_PATH, 'org.freedesktop.DBus.Properties', 'GetAll', 's', iface)
        return _unwrap(r['data'][0]) if r else None

    def call(self, name, method, sig=None, *args):
        a = ['call', name, MPRIS_PATH, PLAYER_IFACE, method]
        if sig:
            a += [sig, *[str(x) for x in args]]
        return self.busctl(*a) is not None

    def info(self, name):
        p = self.props(name) or {}
        root = self.props(name, 'org.mpris.MediaPlayer2') or {}
        md = p.get('Metadata') or {}
        artist = md.get('xesam:artist') or []
        return dict(name=name, identity=root.get('Identity') or name[len(MPRIS_PREFIX):],
                    status=p.get('PlaybackStatus', '?'), title=md.get('xesam:title', ''),
                    artist=', '.join(artist) if isinstance(artist, list) else str(artist),
                    trackid=str(md.get('mpris:trackid', '')), url=md.get('xesam:url', ''),
                    length=(md.get('mpris:length') or 0) / 1e6, position=(p.get('Position') or 0) / 1e6,
                    can_seek=bool(p.get('CanSeek')), can_control=bool(p.get('CanControl', True)),
                    volume=p.get('Volume'), art=str(md.get('mpris:artUrl', '')))

    def pause_all_playing(self, except_name=None):
        for n in self.names(local_only=True):
            if n == except_name:
                continue
            p = self.props(n)
            if p and p.get('PlaybackStatus') == 'Playing':
                log('pausing other player', n)
                self.call(n, 'Pause')


def family(name):
    """'org.mpris.MediaPlayer2.chromium.instance1234' -> 'chromium' (stable across restarts)."""
    return re.sub(r'\.instance_?\d+.*$', '', name[len(MPRIS_PREFIX):] if name.startswith(MPRIS_PREFIX) else name)


class StreamVolume:
    """Best-effort fades for a streaming player via its PipeWire stream (pactl sink-input volume).
    Always restores the original volume. If no stream is found, nothing happens."""

    def __init__(self, fam):
        self.fam = fam.split('.')[0].lower().replace('_', '-')
        self.orig = {}

    def inputs(self):
        out = run(['pactl', '-f', 'json', 'list', 'sink-inputs'])
        try:
            items = json.loads(out) if out else []
        except ValueError:
            return []
        res = []
        for it in items:
            pr = it.get('properties', {})
            text = ' '.join(str(pr.get(k, '')) for k in ('application.name', 'application.process.binary',
                                                         'application.id', 'node.name')).lower()
            if self.fam and self.fam in text and 'mpv' not in text:
                res.append(it)
        return res

    def grab(self):
        for it in self.inputs():
            if it['index'] not in self.orig:
                self.orig[it['index']] = 65536    # restore to 100 % (Spotify must sit at 100 % for the test)
        return bool(self.orig)

    def scale(self, f):
        for idx, v in self.orig.items():
            run(['pactl', 'set-sink-input-volume', str(idx), str(int(v * f))], 1.0)

    def ramp(self, a, b, dur=0.5, steps=10):
        if not self.orig:
            return
        for i in range(steps + 1):
            self.scale(a + (b - a) * i / steps)
            time.sleep(dur / steps)

    def restore(self):
        self.scale(1.0)


# ----------------------------------------------------------------------------------------------------
# The panel: what is playing now, the test-track sequencer, library playback
# ----------------------------------------------------------------------------------------------------
class Panel:
    def __init__(self, store, null_audio):
        self.store = store
        self.s = store.s
        self.loud = Loudness(store)
        self.mpris = Mpris()
        self.lock = threading.RLock()          # protects "what is playing" and the start/stop actions
        self.cancel = threading.Event()
        self.worker = None
        self.cur = None                        # dict describing the current item (or the gap between two)
        self.chain = None                      # {'labels': [...], 'index': i}
        self.mode = None                       # None | 'test' | 'stream' | 'library' | 'gap'
        self.finished_at = None
        self.message = ''                      # last error/info shown in the now-playing bar
        self.track_warn = {i: '' for i in range(4)}
        self.players_cache, self.output_cache = [], {}
        self.lib = {'root': None, 'artists': [], 'scanned': 0}
        self.lib_gain_note = ''
        self.minidsp = MiniDSPControl(null_audio)
        self.solo = SoloLink(self)
        self.mpv = Mpv(null_audio, self.s.get('audio_device', 'auto'), self._mpv_event)
        self.null_audio = null_audio
        self.scan_library()
        self._check_device()
        threading.Thread(target=self._measure_all, daemon=True).start()
        threading.Thread(target=self._poll_loop, daemon=True).start()
        threading.Thread(target=self.solo.resume, daemon=True).start()

    # ---------- library ----------
    def library_root(self):
        cands = ([self.s['library_dir']] if self.s.get('library_dir') else []) + LIBRARY_CANDIDATES
        for c in cands:
            if c and dir_ok(c):
                return c
        return None

    def scan_library(self):
        root = self.library_root()
        artists = []
        if root:
            try:
                for a in sorted(os.scandir(root), key=lambda e: e.name.lower()):
                    if not a.is_dir() or a.name.startswith('.'):
                        continue
                    albums = []
                    for al in sorted(os.scandir(a.path), key=lambda e: e.name.lower()):
                        if not al.is_dir():
                            continue
                        tr = sorted((t.name for t in os.scandir(al.path) if t.name.lower().endswith(AUDIO_EXT)),
                                    key=str.lower)
                        if tr:
                            albums.append(dict(name=al.name, tracks=[dict(name=os.path.splitext(t)[0],
                                                                           rel=f'{a.name}/{al.name}/{t}') for t in tr]))
                    if albums:
                        artists.append(dict(name=a.name, albums=albums))
            except OSError as e:
                log('library scan failed:', e)
        self.lib = {'root': root, 'artists': artists, 'scanned': time.time()}
        self.lib_set = {tr['rel'] for a in artists for al in a['albums'] for tr in al['tracks']}
        for a in artists:                      # durations from the cache now, the rest in the background
            for al in a['albums']:
                for tr in al['tracks']:
                    tr['dur'] = self.store.cache.get('dur|' + tr['rel'])
        threading.Thread(target=self._durations, args=(root, artists), daemon=True).start()
        log('library:', root, f'({sum(len(al["tracks"]) for a in artists for al in a["albums"])} tracks)')

    def _durations(self, root, artists):
        changed = False
        for a in artists:
            for al in a['albums']:
                for tr in al['tracks']:
                    if tr.get('dur'):
                        continue
                    out = run(['ffprobe', '-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0',
                               os.path.join(root, tr['rel'])], 10)
                    try:
                        tr['dur'] = round(float(out), 1)
                        self.store.cache['dur|' + tr['rel']] = tr['dur']
                        changed = True
                    except (TypeError, ValueError):
                        pass
        if changed:
            self.store.save_cache()

    def abs_path(self, rel):
        if os.path.isabs(rel):
            return rel
        root = self.lib['root'] or self.library_root()
        return os.path.join(root, rel) if root else None

    # ---------- loudness of the test tracks ----------
    def track_loudness(self, i, wait=True):
        t = self.s['tracks'][i]
        if t.get('kind') != 'local':
            return None
        start, length, fade = float(t['start']), float(t['length']), float(self.s['fade'])
        key = Loudness.key(t['source'], start, length, True, fade)
        hit = self.loud.cached(key)
        if hit or not wait:
            return hit
        p = self.abs_path(t['source'])
        if not p or not os.path.exists(p):
            return None
        return self.loud.measure(p, t['source'], start, length, True, fade)

    def _measure_all(self):
        for i in range(4):
            try:
                self.track_loudness(i)
            except Exception as e:
                log('measure error', e)

    # ---------- device ----------
    def _check_device(self):
        dev = self.s.get('audio_device', 'auto')
        if self.null_audio or dev in ('auto', 'pipewire'):
            return
        names = [d['name'] for d in (self.mpv.get('audio-device-list') or [])]
        if dev not in names:
            self.message = f'Saved output "{dev}" is not connected; using the system default instead.'
            log(self.message)
            self.mpv.set('audio-device', 'auto')

    def set_device(self, dev):
        self.s['audio_device'] = dev
        self.store.save()
        if not self.null_audio:
            self.mpv.set('audio-device', dev)
            self.mpv.device = dev

    # ---------- stopping ----------
    def _stop_now(self):
        """Stop whatever plays (mpv and the streaming player of the current item). Caller holds self.lock."""
        self.cancel.set()
        cur = self.cur
        if cur and cur.get('kind') == 'stream' and cur.get('name'):
            sv = cur.get('sv')
            if cur.get('running') and cur.get('t_run') and sv:
                sv.ramp(1, 0, float(self.s['fade']))
            if cur.get('running') or cur.get('phase') == 'loading':
                self.mpris.call(cur['name'], 'Pause')
            if sv:
                sv.restore()
        if self.mode in ('test', 'library', 'tone') or (self.mpv.props.get('idle-active') is False):
            self.mpv.fade_stop()
        self.cur, self.mode, self.chain = None, None, None
        # No join on the worker: every action it takes checks `cancel` under self.lock first.

    def stop(self):
        with self.lock:
            self._stop_now()
            self.finished_at = None
            self.message = ''

    # ---------- test tracks (local or stream), chained ----------
    @staticmethod
    def _cue_file(cue):
        """cues/<name>.wav for a valid cue name (a1..d2 announcements, ra1..rd2 'please rate'), else None."""
        if not cue or not re.fullmatch(r'r?[a-d][1-4xy]|end', str(cue)):
            return None
        p = HERE / 'cues' / f'{cue}.wav'
        return p if p.exists() else None

    def play_tracks(self, idx_list, label=None, cue=None, after_cue=None):
        idx_list = [int(i) for i in idx_list if 0 <= int(i) < 4]
        cue_path, after_path = self._cue_file(cue), self._cue_file(after_cue)
        if not idx_list and cue_path is None:              # nothing to play (a voice-only step needs its cue)
            return
        with self.lock:
            self._stop_now()
            self.cancel = threading.Event()
            self.message = ''
            self.finished_at = None
            labels = [f'Track {i + 1}' for i in idx_list]
            self.chain = {'labels': labels, 'index': 0, 'name': label or ' → '.join(labels)}
            cancel = self.cancel
            self.worker = threading.Thread(target=self._run_chain, args=(idx_list, cancel, cue_path, after_path), daemon=True)
            self.worker.start()

    def _run_chain(self, idx_list, cancel, cue_path=None, after_path=None):
        if cue_path is not None:                            # spoken step announcement before the music
            if not self._play_cue(cue_path, cancel) or cancel.wait(1.0):
                return
        for n, i in enumerate(idx_list):
            if cancel.is_set():
                return
            if n > 0:
                gap = float(self.s.get('gap', 2))
                with self.lock:
                    if cancel.is_set():
                        return
                    self.mode = 'gap'
                    self.cur = {'kind': 'gap', 'until': time.monotonic() + gap, 'next': f'Track {i + 1}'}
                    self.chain['index'] = n
                if cancel.wait(gap):
                    return
            t = self.s['tracks'][i]
            ok = (self._play_local(i, cancel) if t.get('kind') != 'stream' else self._play_stream(i, cancel))
            if not ok or cancel.is_set():
                return
        if after_path is not None:                          # "Please rate ... now." after the music
            if cancel.wait(0.8) or not self._play_cue(after_path, cancel):
                return
        with self.lock:
            if not cancel.is_set():
                self.cur, self.mode, self.chain = None, None, None
                self.finished_at = time.monotonic()

    def _play_cue(self, path, cancel):
        """Play a spoken cue (cues/*.wav, already levelled to -23 LUFS). Returns False if cancelled or failed."""
        with self.lock:
            if cancel.is_set():
                return False
            self.mpris.pause_all_playing()
            self.mpv.set('volume', 100)
            self.mpv.set('volume-gain', 0)
            self.mpv.set('pause', False)          # a Pause pressed earlier must not carry over
            r = self.mpv.cmd({'name': 'loadfile', 'url': str(path), 'flags': 'replace', 'options': {'af': ''}})
            eid = (r.get('data') or {}).get('playlist_entry_id')
            if r.get('error') != 'success' or eid is None:
                return True                                 # a missing cue must never block the test: just skip it
            self.mode = 'test'
            self.cur = {'kind': 'cue', 'rate': path.stem.startswith('r'),
                        'title': 'Voice: please rate now' if path.stem.startswith('r') else
                        'Voice: thank you, the test is finished' if path.stem == 'end' else 'Voice: step announcement'}
        reason = self.mpv.wait_end(eid, cancel)
        t_end = time.monotonic() + 2
        while reason == 'eof' and not self.mpv.props.get('idle-active') and time.monotonic() < t_end:
            if cancel.wait(0.02):
                return False
        return not cancel.is_set()

    def _play_local(self, i, cancel):
        t = self.s['tracks'][i]
        p = self.abs_path(t['source'])
        if not p or not os.path.exists(p):
            self._fail(cancel, f'Track {i + 1}: file not found ({t["source"]}). Check the library folder.')
            return False
        with self.lock:
            if cancel.is_set():
                return False
            self.mode, self.cur = 'test', {'kind': 'measuring', 'track': i}
        L = self.track_loudness(i)                         # usually cached; otherwise about 1 s
        if not L:
            self._fail(cancel, f'Track {i + 1}: loudness measurement failed, not playing it unmatched.')
            return False
        start, length, fade = float(t['start']), float(t['length']), float(self.s['fade'])
        gain = float(self.s['target_lufs']) - L['lufs']
        with self.lock:
            if cancel.is_set():
                return False
            self.mpris.pause_all_playing()
            self.mpv.set('volume', 100)
            self.mpv.set('volume-gain', 0)
            self.mpv.set('pause', False)          # a Pause pressed earlier must not carry over
            r = self.mpv.cmd({'name': 'loadfile', 'url': p, 'flags': 'replace',
                              'options': {'start': f'{start}', 'end': f'{start + length}',
                                          'af': self._test_af(start, start + length, fade, gain)}})
            eid = (r.get('data') or {}).get('playlist_entry_id')
            if r.get('error') != 'success' or eid is None:
                self._fail(cancel, f'Track {i + 1}: mpv refused to play ({r.get("error")}).')
                return False
            self.cur = dict(kind='local', track=i, start=start, end=start + length, gain=gain, eid=eid,
                            title=self._title_of(t['source']), fade=fade)
        reason = self.mpv.wait_end(eid, cancel)
        if reason not in (None, 'eof'):
            self._fail(cancel, f'Track {i + 1}: playback ended with "{reason}".')
            return False
        # mpv reports the end when the file is decoded; the sound card still plays ~0.3 s. Wait for that.
        t_end = time.monotonic() + 2
        while reason == 'eof' and not self.mpv.props.get('idle-active') and time.monotonic() < t_end:
            if cancel.wait(0.02):
                return False
        return reason == 'eof'

    @staticmethod
    def _test_af(start, end, fade, gain):
        # Fades use the file's own time stamps (mpv passes them to the filter), so st= is absolute.
        return (f'lavfi=[aformat=channel_layouts=stereo,{MONO_PAN},afade=t=in:st={start}:d={fade},'
                f'afade=t=out:st={end - fade}:d={fade},volume={gain:.2f}dB]')

    def _title_of(self, rel):
        parts = rel.split('/')
        name = os.path.splitext(parts[-1])[0]
        name = re.sub(r'^\d+(-\d+)?\s*-\s*', '', name)
        return f'{parts[0]} – {name}' if len(parts) >= 3 else name

    def _fail(self, cancel, msg):
        log(msg)
        with self.lock:
            if not cancel.is_set():
                self.message = msg
                self.cur, self.mode, self.chain = None, None, None

    def resolve_player(self, wanted):
        names = self.mpris.names(local_only=True)
        if wanted in names:
            return wanted
        fam = family(wanted)
        same = [n for n in names if family(n) == fam]
        return same[0] if same else None

    def _play_stream(self, i, cancel):
        t = self.s['tracks'][i]
        name = self.resolve_player(t.get('player', ''))
        if not name:
            self._fail(cancel, f'Track {i + 1}: player "{family(t.get("player", "")) or "?"}" is not running. '
                               'Start it (and open the track in it), then try again.')
            return False
        info = self.mpris.info(name)
        if not info['can_control']:
            self._fail(cancel, f'Track {i + 1}: {info["identity"]} does not allow remote control.')
            return False
        start, length, fade = float(t['start']), float(t['length']), float(self.s['fade'])
        uri = t.get('uri', '') if family(name) == 'spotify' else ''
        if uri and uri.rsplit(':', 1)[1] in info['trackid'] + info['url']:
            uri = ''                           # already loaded: re-opening would restart it at 0:00 after our seek
        warn = []
        sv = StreamVolume(family(name))
        with self.lock:
            if cancel.is_set():
                return False
            self.mode = 'stream'
            self.cur = dict(kind='stream', track=i, name=name, phase='loading', start=start, length=length,
                            title=info['identity'], sv=sv, running=False, t_run=None)
            if self.mpv.props.get('idle-active') is False:
                self.mpv.fade_stop()
            self.mpris.pause_all_playing(except_name=name)
            if sv.grab():
                sv.scale(0)                    # silent while loading/seeking (only if the stream exists already)
            before = info['trackid']
            if uri:
                self.mpris.call(name, 'OpenUri', 's', uri)
        t_open = None                          # when the new track appeared after OpenUri
        if uri:                                # wait until the player shows the new track
            tid = uri.rsplit(':', 1)[1]
            t_end = time.monotonic() + 10
            while True:
                if cancel.wait(0.05):
                    return False
                info = self.mpris.info(name)
                if tid in info['trackid'] or tid in info['url']:
                    break
                if info['trackid'] and info['trackid'] != before and time.monotonic() > t_end - 9:
                    break                      # Spotify may "relink" a track to another id in this country
                if time.monotonic() > t_end:
                    sv.restore()
                    self._fail(cancel, f'Track {i + 1}: {info["identity"]} did not load {uri} within 10 s.')
                    return False
            t_open = time.monotonic()
            # OpenUri's own start lands late and would undo our seek: wait until the new track really plays
            t_end = time.monotonic() + 5
            while time.monotonic() < t_end:
                p = self.mpris.props(name) or {}
                if p.get('PlaybackStatus') == 'Playing' and (p.get('Position') or 0) >= 0.3e6:
                    break
                if cancel.wait(0.05):
                    return False
        with self.lock:
            if cancel.is_set():
                return False
            self.mpris.call(name, 'Pause')
            info = self.mpris.info(name)
            if info['length'] and start + length > info['length'] + 0.5:
                warn.append(f'the track is only {fmt_time(info["length"])} long')
            if start > 0 or info['position'] > 1:
                if not info['can_seek']:
                    warn.append(f'{info["identity"]} cannot seek: starts at {fmt_time(info["position"])}')
                else:
                    ok = bool(info['trackid']) and self.mpris.call(name, 'SetPosition', 'ox', info['trackid'],
                                                                   int(start * 1e6))
                    if not ok:                 # fallback: relative seek from where it is now
                        self.mpris.call(name, 'Seek', 'x', int((start - info['position']) * 1e6))
                    time.sleep(0.3)
            sv.grab()                          # the stream may only exist now
            sv.scale(0)
            self.mpris.call(name, 'Play')
            self.cur.update(title=f'{info["artist"]} – {info["title"]}' if info['title'] else info['identity'])
            if info['title']:
                t['title'] = f'{info["artist"]} – {info["title"]}'
        # Spotify's clock is the truth. Stay silent until it really plays at the start position.
        # Spotify undoes the first seek after a track change about 0.6 s later, so the position must hold
        # for 0.8 s; then one more seek to the start (that one sticks), and only then the fade-in.
        # About 1.8 s after OpenUri Spotify also jumps on its own: back to 0:00, or forward to where a
        # track it played before was left. So the final seek waits until 2.5 s after the track appeared,
        # and any position outside the start window (before or after it) is sought again.
        seekable = info['can_seek'] and bool(info['trackid']) and (start > 0 or info['position'] > 1 or bool(uri))

        def seek_to(x):
            with self.lock:
                if cancel.is_set():
                    return False
                self.mpris.call(name, 'SetPosition', 'ox', info['trackid'], int(x * 1e6))
            return True

        t0, seeks, ok_since, final, replayed = time.monotonic(), 0, None, False, False
        while True:
            if cancel.wait(0.05):
                return False
            p = self.mpris.props(name) or {}
            st, pos = p.get('PlaybackStatus'), (p.get('Position') or 0) / 1e6
            now = time.monotonic()
            if st == 'Playing' and not seekable:
                break
            if st == 'Playing' and start - 0.5 <= pos <= start + 3:
                ok_since = ok_since or now
                if final and pos <= start + 0.5:
                    break
                if not final and now - ok_since >= 0.8 and (t_open is None or now - t_open >= 2.5):
                    if not seek_to(start):
                        return False
                    final, ok_since, t0 = True, None, now
                    continue
            else:
                ok_since = None
                if st == 'Playing' and seekable and seeks < 4 and now - t0 > 0.3:
                    log(f'Track {i + 1}: position {pos:.1f} s instead of {start:.1f} s, seeking again')
                    if not seek_to(start):
                        return False
                    seeks, final, t0 = seeks + 1, False, now
            if st != 'Playing' and not replayed and now - t0 > 3:
                log(f'Track {i + 1}: {info["identity"]} is {st}, sending Play again')
                with self.lock:
                    if cancel.is_set():
                        return False
                    self.mpris.call(name, 'Play')
                replayed = True
            if now - t0 > (6 if st == 'Playing' else 10):
                if st == 'Playing':
                    warn.append(f'{info["identity"]} did not seek: starts at {fmt_time(pos)}')
                    break
                sv.restore()
                self._fail(cancel, f'Track {i + 1}: {info["identity"]} did not start playing within 10 s.')
                return False
        with self.lock:
            if cancel.is_set():
                return False
            now = time.monotonic()
            self.cur.update(phase='playing', running=True, t_run=now, pos=pos, pos_at=now, playing=True)
        self.track_warn[i] = '; '.join(warn)
        if warn:
            log(f'Track {i + 1}:', self.track_warn[i])
        self.store.save()                      # keeps the title on the row
        sv.ramp(0, 1, min(fade, 0.5))
        # follow Spotify's Position: fade out over the last `fade` seconds, pause at start + length.
        # Safety: if Position stops moving, give up after length + 10 s of playing time.
        played, last = 0.0, time.monotonic()
        while True:
            with self.lock:
                c = self.cur
                if cancel.is_set() or c is None:   # Stop cleared cur while this thread was between reads
                    return False
                end = start + c['length']
                near = c['pos'] >= end - fade - 0.4
            if cancel.wait(0.05 if near else 0.25):
                return False
            p = self.mpris.props(name)
            with self.lock:
                if cancel.is_set():
                    return False
                now = time.monotonic()
                if c.get('t_run') and c.get('playing'):
                    played += now - last
                last = now
                if p:
                    c['pos'] = (p.get('Position') or 0) / 1e6
                    c['pos_at'] = now
                    c['playing'] = p.get('PlaybackStatus') == 'Playing'
                pos = c['pos']
                end = start + c['length']
                if (seekable and c['playing'] and played < 5 and info['trackid']
                        and (pos < start - 1 or pos > start + played + 3)):
                    log(f'Track {i + 1}: Spotify jumped to {pos:.1f} s, seeking to {start:.1f} s again')
                    sv.scale(0)
                    self.mpris.call(name, 'SetPosition', 'ox', info['trackid'], int(start * 1e6))
                    c['pos'], c['pos_at'] = start, now
                    continue
                if pos >= end - 0.15:          # Spotify needs ~0.2 s to act on Pause; the fade is at 0 by then
                    break
                if played > c['length'] + 10:
                    log(f'Track {i + 1}: Spotify position stuck at {pos:.1f} s, stopping on the safety timeout')
                    break
                if sv.orig and fade > 0:
                    sv.scale(min(1.0, max(0.0, (end - 0.15 - pos) / fade)))
        with self.lock:
            if cancel.is_set():
                return False
            sv.scale(0)
            self.mpris.call(name, 'Pause')
            sv.restore()
            self.cur['running'] = False
            self.cur['t_run'] = None
        return True

    def _elapsed(self):
        """Stream items: Spotify's Position minus the start (extrapolated between reads, at most 1 s)."""
        c = self.cur or {}
        if c.get('kind') != 'stream' or 'pos' not in c:
            return 0.0
        pos = c['pos']
        if c.get('t_run') and c.get('playing'):
            pos += min(1.0, time.monotonic() - c['pos_at'])
        return max(0.0, pos - c['start'])

    # ---------- transport (pause, extend, seek, next/prev) ----------
    def pause_toggle(self):
        with self.lock:
            c = self.cur or {}
            if c.get('kind') == 'stream' and c.get('phase') == 'playing':
                if c.get('t_run'):
                    self.mpris.call(c['name'], 'Pause')
                    c['t_run'], c['playing'] = None, False
                else:
                    self.mpris.call(c['name'], 'Play')
                    c['t_run'], c['pos_at'] = time.monotonic(), time.monotonic()
            elif self.mode in ('test', 'library', 'tone'):
                self.mpv.cmd(['cycle', 'pause'])

    def extend(self, secs):
        """Make the excerpt that plays now longer (this play only)."""
        with self.lock:
            c = self.cur or {}
            if c.get('kind') == 'local':
                c['end'] += secs
                self.mpv.set('end', f'{c["end"]}')
                self.mpv.set('af', self._test_af(c['start'], c['end'], c['fade'], c['gain']))
            elif c.get('kind') == 'stream':
                c['length'] += secs

    def seek(self, pos):
        with self.lock:
            if self.mode == 'library':
                self.mpv.cmd(['seek', float(pos), 'absolute'])

    def lib_step(self, d):
        with self.lock:
            if self.mode == 'library':
                self.mpv.cmd(['playlist-next' if d > 0 else 'playlist-prev', 'force'])

    # ---------- library playback ----------
    def play_library(self, rels, index=0):
        with self.lock:
            self._stop_now()
            self.cancel = threading.Event()
            self.message, self.finished_at = '', None
            paths = [self.abs_path(r) for r in rels]
            if not paths or not all(paths):
                self.message = 'Library folder not found.'
                return
            self.mpris.pause_all_playing()
            self.mode = 'library'
            self.cur = {'kind': 'library', 'rels': rels}
            self.lib_rels = dict(zip(paths, rels))
            self.mpv.set('volume', 100)
            self._set_lib_gain(paths[index], rels[index], wait=True)   # measure the first track before it starts
            opts = {'af': f'lavfi=[aformat=channel_layouts=stereo,{MONO_PAN}]'} if self.s.get('lib_mono') else {}
            self.mpv.cmd(['stop'])
            self.mpv.cmd(['playlist-clear'])
            for p in paths:                    # queue the album, then start at the chosen track
                self.mpv.cmd({'name': 'loadfile', 'url': p, 'flags': 'append', 'options': opts})
            self.mpv.set('pause', False)
            self.mpv.set('playlist-pos', index)
        pairs = list(zip(paths, rels))
        todo = pairs[index + 1:] + pairs[:index]          # measure the next tracks first
        threading.Thread(target=lambda: [self._lib_loud(p, r) for p, r in todo], daemon=True).start()

    def _lib_loud(self, p, r):
        if not self.s.get('lib_match'):
            return None
        return self.loud.measure(p, r, None, None, bool(self.s.get('lib_mono')))

    def _set_lib_gain(self, p, r, wait):
        off = float(self.s.get('lib_offset', 0))
        if not self.s.get('lib_match'):
            self.mpv.set('volume-gain', max(-96.0, min(0.0, off)))
            self.lib_gain_note = f'{off:+.1f} dB (no loudness match)'
            return
        key = Loudness.key(r, 0, 0, bool(self.s.get('lib_mono')), 0)
        L = self.loud.cached(key) or (self._lib_loud(p, r) if wait else None)
        if not L:
            self.mpv.set('volume-gain', -12.0)         # safe level until the measurement is done
            self.lib_gain_note = 'measuring loudness (−12 dB meanwhile)'
            threading.Thread(target=lambda: (self._lib_loud(p, r), self._lib_gain_if_current(p, r)), daemon=True).start()
            return
        target = float(self.s['target_lufs']) + off
        gain = min(target - L['lufs'], -1.0 - L['peak'])       # never let a peak go above -1 dBTP
        gain = max(-96.0, min(12.0, gain))
        self.mpv.set('volume-gain', round(gain, 2))
        self.lib_gain_note = f'{gain:+.1f} dB → {L["lufs"] + gain:.1f} LUFS'

    def _lib_gain_if_current(self, p, r):
        if self.mode == 'library' and self.mpv.props.get('path') == p:
            self._set_lib_gain(p, r, wait=False)

    def _mpv_event(self, m):
        # a new library track starts: set its loudness-matched gain
        if m.get('event') == 'start-file' and self.mode == 'library':
            threading.Thread(target=self._on_lib_track, daemon=True).start()

    def _on_lib_track(self):
        p = self.mpv.get('path')
        r = getattr(self, 'lib_rels', {}).get(p)
        if p and r:
            self._set_lib_gain(p, r, wait=False)

    # ---------- check tones (loop until Stop, played exactly as the file is: no gain, no filter) ----------
    def play_tone(self, which):
        fname = TONES.get(str(which))
        path = next((os.path.join(d, fname) for d in TONE_DIRS if fname and os.path.exists(os.path.join(d, fname))), None)
        with self.lock:
            self._stop_now()
            self.cancel = threading.Event()
            self.finished_at = None
            if not path:
                self.message = f'Check tone {which} Hz not found in {TONE_DIRS[0]} or on the USB stick.'
                return
            self.message = ''
            self.mpris.pause_all_playing()
            self.mpv.set('volume', 100)
            self.mpv.set('volume-gain', 0)
            self.mpv.set('pause', False)          # a Pause pressed earlier must not carry over
            self.mpv.cmd({'name': 'loadfile', 'url': path, 'flags': 'replace', 'options': {'loop-file': 'inf'}})
            self.mode = 'tone'
            self.cur = {'kind': 'tone', 'title': f'Check tone {which} Hz, −12 dBFS (loops until Stop)'}

    # ---------- streaming players (Players tab) ----------
    def player_action(self, name, action):
        if action not in ('PlayPause', 'Play', 'Pause', 'Next', 'Previous', 'Stop') or self.mpris.is_remote(name):
            return
        if action in ('PlayPause', 'Play'):
            with self.lock:                     # never two sources at once
                if self.mode:
                    self._stop_now()
                elif self.mpv.props.get('idle-active') is False:
                    self.mpv.fade_stop()
            self.mpris.pause_all_playing(except_name=name)
        self.mpris.call(name, action)

    def reset_stream(self, name):
        sv = StreamVolume(family(name))
        sv.grab()
        for idx in sv.orig:
            run(['pactl', 'set-sink-input-mute', str(idx), '0'])
            run(['pactl', 'set-sink-input-volume', str(idx), '100%'])

    def track_alt(self, i, action, j=None):
        """Alternative songs per test track. save: keep a copy of the current song (then edit the row to the new one).
        use: swap alternative j with the current song. delete: forget alternative j."""
        t = self.s['tracks'][i]
        alts = t.setdefault('alts', [])
        cur = {k: t.get(k) for k in SONG_FIELDS}
        if action == 'save':
            if len(alts) >= 6:
                return 'At most 6 alternatives per track.'
            alts.append(cur)
        elif action in ('use', 'delete') and j is not None and 0 <= int(j) < len(alts):
            j = int(j)
            if action == 'use':
                new = alts[j]
                alts[j] = cur
                for k in SONG_FIELDS:
                    if k in new:
                        t[k] = new[k]
                self.track_warn[i] = ''
            else:
                alts.pop(j)
        else:
            return 'Nothing changed.'
        self.store.save()
        threading.Thread(target=self._measure_all, daemon=True).start()
        return ''

    def load_title(self, i):
        t = self.s['tracks'][i]
        name = self.resolve_player(t.get('player', ''))
        if not name:
            return f'{family(t.get("player", ""))} is not running.'
        info = self.mpris.info(name)
        if not info['title']:
            return f'{info["identity"]} has no track loaded.'
        t['title'] = f'{info["artist"]} – {info["title"]}'
        uri = t.get('uri', '')
        note = ''
        if family(name) == 'spotify' and uri and uri.rsplit(':', 1)[1] not in info['trackid'] + info['url']:
            note = ' (note: that is what Spotify has loaded now, not this row\'s link)'
        self.store.save()
        return 'Loaded: ' + t['title'] + note

    # ---------- background polling of players and output ----------
    def _poll_loop(self):
        while True:
            try:
                self.players_cache = self._players()
            except Exception as e:
                log('player poll error', e)
            try:
                self.output_cache = self._output()
            except Exception as e:
                log('output poll error', e)
            time.sleep(1.5)

    def _players(self):
        res = []
        sinks = self._sinks()
        pa = run(['pactl', '-f', 'json', 'list', 'sink-inputs'])
        try:
            inputs = json.loads(pa) if pa else []
        except ValueError:
            inputs = []
        for n in self.mpris.names():
            info = self.mpris.info(n)
            fam = family(n).split('.')[0].lower()
            st = []
            for it in inputs:
                pr = it.get('properties', {})
                text = ' '.join(str(pr.get(k, '')) for k in ('application.name', 'application.process.binary',
                                                             'application.id', 'node.name')).lower()
                if fam and fam in text:
                    vols = [c.get('value_percent', '') for c in it.get('volume', {}).values()]
                    st.append(dict(volume=vols[0] if vols else '?', mute=it.get('mute'),
                                   sink=sinks.get(it.get('sink'), {}).get('description', '?')))
            info['family'] = family(n)
            info['streams'] = st
            info['remote'] = self.mpris.is_remote(n, info['identity'])
            res.append(info)
        return res

    def _sinks(self):
        out = run(['pactl', '-f', 'json', 'list', 'sinks'])
        try:
            return {s['index']: s for s in json.loads(out)} if out else {}
        except ValueError:
            return {}

    def _output(self):
        default = (run(['pactl', 'get-default-sink']) or '').strip()
        sinks = self._sinks()
        d = next((s for s in sinks.values() if s.get('name') == default), {})
        vols = [c.get('value_percent', '') for c in d.get('volume', {}).values()]
        return dict(default_name=default, default_desc=d.get('description', default or 'unknown'),
                    default_volume=vols[0] if vols else '?', default_mute=d.get('mute', False))

    def devices(self):
        lst = self.mpv.get('audio-device-list') or []
        return [d for d in lst if d['name'] in ('auto',) or d['name'].startswith('pipewire/')]

    # ---------- status for the page ----------
    def status(self):
        with self.lock:
            c = dict(self.cur or {})
            mode = self.mode
        pr = self.mpv.props
        now = dict(mode=mode, message=self.message, paused=bool(pr.get('pause')), chain=self.chain)
        if c.get('kind') == 'local':
            tp = pr.get('time-pos') or c['start']
            now.update(track=c['track'], title=c['title'], elapsed=max(0.0, tp - c['start']),
                       length=c['end'] - c['start'], gain=c['gain'], source='local')
        elif c.get('kind') == 'measuring':
            now.update(track=c['track'], title='measuring loudness …', elapsed=0, length=0)
        elif c.get('kind') == 'stream':
            now.update(track=c['track'], title=c['title'], elapsed=self._elapsed(),
                       length=c['length'], source='stream', phase=c['phase'], paused=c.get('t_run') is None
                       and c['phase'] == 'playing')
        elif c.get('kind') == 'cue':
            now.update(title=c['title'], elapsed=self.mpv.props.get('time-pos') or 0, length=0, cue=True, rate=c.get('rate', False))
        elif c.get('kind') == 'gap':
            now.update(gap_left=max(0.0, c['until'] - time.monotonic()), next=c['next'])
        elif c.get('kind') == 'tone':
            now.update(title=c['title'], elapsed=pr.get('time-pos') or 0, length=0)
        elif c.get('kind') == 'library':
            now.update(title=pr.get('media-title') or '', finished=bool(pr.get('idle-active')), elapsed=pr.get('time-pos') or 0,
                       length=pr.get('duration') or 0, playlist_pos=pr.get('playlist-pos'),
                       playlist_count=pr.get('playlist-count'), path=pr.get('path'), gain_note=self.lib_gain_note)
        if mode is None and self.finished_at:
            now['since_end'] = time.monotonic() - self.finished_at
        tracks = []
        for i, t in enumerate(self.s['tracks']):
            info = dict(warn=self.track_warn.get(i, ''))
            if t.get('kind') != 'stream':
                info['exists'] = t['source'] in self.lib_set or (os.path.isabs(t['source']) and os.path.exists(t['source']))
                L = self.track_loudness(i, wait=False)
                if L:
                    g = float(self.s['target_lufs']) - L['lufs']
                    info.update(lufs=L['lufs'], gain=g, peak_after=L['peak'] + g)
            tracks.append(info)
        return dict(now=now, tracks=tracks, mpv_ok=self.mpv.alive, null_audio=self.null_audio,
                    library_root=self.lib['root'], output=self.output_cache,
                    audio_device=self.s.get('audio_device', 'auto'),
                    minidsp=self.minidsp.status(self.s.get('minidsp_auto', False)),
                    mpv_device=pr.get('audio-device'))

    def set_minidsp_gains(self, body):
        if not self.s.get('minidsp_auto', False):
            raise MiniDSPError('MiniDSP control is off: turn on "Apply test gains automatically" in Output first')
        return self.minidsp.set_gains(body.get('output1'), body.get('output2'))

    def close(self):
        self.solo.close()
        with self.lock:
            try:
                self._stop_now()
            except Exception:
                pass
        self.mpv.close()


# ----------------------------------------------------------------------------------------------------
# HTTP server
# ----------------------------------------------------------------------------------------------------
TRACK_FIELDS = ('label', 'kind', 'source', 'start', 'length', 'player', 'uri', 'title')


def update_settings(panel, body):
    s = panel.s
    if 'tracks' in body:
        for i, nt in enumerate(body['tracks'][:4]):
            t = s['tracks'][i]
            for k in TRACK_FIELDS:
                if k not in nt:
                    continue
                v = nt[k]
                if k in ('start', 'length'):
                    v = round(parse_time(v), 2)
                    if k == 'length':
                        v = max(1.5, v)
                    if k == 'start':
                        v = max(0.0, v)
                elif k == 'kind':
                    v = 'stream' if v == 'stream' else 'local'
                elif k == 'uri':
                    v = spotify_uri(v) or str(v).strip()
                if t.get(k) != v:
                    if k in ('uri', 'player', 'kind'):
                        panel.track_warn[i] = ''
                    if k == 'uri':
                        t['title'] = ''
                t[k] = v
    for k in ('gap', 'target_lufs', 'lib_offset', 'rate_secs'):
        if k in body:
            s[k] = float(body[k])
    for k in ('lib_mono', 'lib_match', 'part_d', 'cues', 'auto', 'minidsp_auto'):
        if k in body:
            s[k] = bool(body[k])
    for k in ('listener', 'step'):
        if k in body:
            s[k] = max(0 if k == 'step' else 1, int(body[k]))
    if 'library_dir' in body:
        s['library_dir'] = str(body['library_dir']).strip()
        panel.scan_library()
    panel.store.save()
    threading.Thread(target=panel._measure_all, daemon=True).start()   # new start/length -> new gain


def make_handler(panel):
    class H(BaseHTTPRequestHandler):
        def log_message(self, *a):
            pass

        def send(self, code, body, ctype='application/json'):
            data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode()
            self.send_response(code)
            self.send_header('Content-Type', ctype + '; charset=utf-8')
            self.send_header('Cache-Control', 'no-store')
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            p = self.path.split('?')[0]
            try:
                if p in ('/', '/index.html'):
                    return self.send(200, HTML_FILE.read_bytes(), 'text/html')
                if p == '/api/status':
                    return self.send(200, panel.status())
                if p == '/api/settings':
                    return self.send(200, panel.s)
                if p == '/api/library':
                    return self.send(200, dict(panel.lib, candidates=LIBRARY_CANDIDATES,
                                               custom=panel.s.get('library_dir', '')))
                if p == '/api/players':
                    return self.send(200, panel.players_cache)
                if p == '/api/solo':
                    return self.send(200, panel.solo.status())
                if p == '/api/devices':
                    return self.send(200, dict(devices=panel.devices(), selected=panel.s.get('audio_device', 'auto')))
                return self.send(404, {'error': 'not found'})
            except Exception as e:
                log('GET error', p, e)
                return self.send(500, {'error': str(e)})

        def do_POST(self):
            p = self.path.split('?')[0]
            n = int(self.headers.get('Content-Length') or 0)
            try:
                body = json.loads(self.rfile.read(n) or b'{}')
            except ValueError:
                body = {}
            res = {'ok': True}
            try:
                if p == '/api/play':
                    panel.play_tracks(body.get('tracks', []), body.get('label'), body.get('cue'), body.get('after_cue'))
                elif p == '/api/stop':
                    panel.stop()
                elif p == '/api/pause':
                    panel.pause_toggle()
                elif p == '/api/extend':
                    panel.extend(float(body.get('seconds', 30)))
                elif p == '/api/seek':
                    panel.seek(float(body.get('pos', 0)))
                elif p == '/api/next':
                    panel.lib_step(+1)
                elif p == '/api/prev':
                    panel.lib_step(-1)
                elif p == '/api/settings':
                    update_settings(panel, body)
                    res['settings'] = panel.s
                elif p == '/api/settings/reset_tracks':
                    panel.s['tracks'] = json.loads(json.dumps(DEFAULT_TRACKS))
                    panel.store.save()
                    threading.Thread(target=panel._measure_all, daemon=True).start()
                    res['settings'] = panel.s
                elif p == '/api/tone':
                    panel.play_tone(body.get('hz'))
                elif p == '/api/dsp/gains':
                    res['gains'] = panel.set_minidsp_gains(body)
                elif p == '/api/dsp/check':
                    res['message'] = panel.minidsp.check()
                elif p == '/api/solo/start':
                    r = panel.solo.start(body.get('partA', True))
                    res['solo'] = dict(n=r['n'], code=r['code'])
                elif p == '/api/solo/end':
                    panel.solo.end()
                elif p == '/api/dsp/filters':
                    res['filters'] = panel.minidsp.load_filters()
                elif p == '/api/library/rescan':
                    panel.scan_library()
                elif p == '/api/library/play':
                    panel.play_library(body['rels'], int(body.get('index', 0)))
                elif p == '/api/player':
                    panel.player_action(body['name'], body['action'])
                elif p == '/api/player/reset_stream':
                    panel.reset_stream(body['name'])
                elif p == '/api/track/alt':
                    res['message'] = panel.track_alt(int(body['track']), body.get('action'), body.get('index'))
                elif p == '/api/track/load_title':
                    res['message'] = panel.load_title(int(body['track']))
                elif p == '/api/device':
                    panel.set_device(body['device'])
                elif p == '/api/spotify/open':
                    subprocess.Popen(['spotify'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                     start_new_session=True)
                else:
                    return self.send(404, {'error': 'not found'})
            except Exception as e:
                log('POST error', p, e)
                return self.send(500, {'error': str(e)})
            return self.send(200, res)
    return H


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--port', type=int, default=8771)
    ap.add_argument('--test', '--null-audio', dest='null_audio', action='store_true',
                    help='silent test mode: mpv plays to a null output')
    ap.add_argument('--no-browser', action='store_true', help='do not open the browser')
    ap.add_argument('--settings', default=str(HERE / 'panel_settings.json'))
    ap.add_argument('--cache', default=str(HERE / 'loudness_cache.json'))
    a = ap.parse_args()
    url = f'http://127.0.0.1:{a.port}/'
    try:
        srv = ThreadingHTTPServer(('127.0.0.1', a.port), None)
    except OSError:
        print(f'Port {a.port} is busy: the panel is probably running already (or another program uses it: try --port 8772). Opening {url}')
        if not a.no_browser:
            webbrowser.open(url)
        sys.exit(1)
    panel = Panel(Store(a.settings, a.cache), a.null_audio)
    srv.RequestHandlerClass = make_handler(panel)
    srv.daemon_threads = True
    def _quit(*_):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, _quit)                # closing the terminal or `kill` also stops mpv cleanly
    signal.signal(signal.SIGHUP, _quit)
    print(f'\nControl panel running at {url}  (Ctrl+C to quit)\n', flush=True)
    if not a.no_browser:
        threading.Timer(0.5, lambda: webbrowser.open(url)).start()
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        print('\nStopping …')
        panel.close()


if __name__ == '__main__':
    main()
