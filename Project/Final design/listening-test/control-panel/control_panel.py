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
Only the Python standard library is used, plus mpv, ffmpeg, busctl and pactl.
"""
import argparse, ctypes, json, os, re, signal, socket, subprocess, sys, threading, time, webbrowser
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
    listener=1, step=0, lib_mono=True, lib_match=True, lib_offset=0.0, part_d=False)

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


# ----------------------------------------------------------------------------------------------------
# Settings and loudness cache (JSON files next to the script)
# ----------------------------------------------------------------------------------------------------
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

    def names(self):
        r = self.busctl('call', 'org.freedesktop.DBus', '/org/freedesktop/DBus', 'org.freedesktop.DBus', 'ListNames')
        if not r:
            return []
        return sorted(n for n in r['data'][0] if n.startswith(MPRIS_PREFIX))

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
        for n in self.names():
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
                vols = [c['value'] for c in it.get('volume', {}).values()] or [65536]
                self.orig[it['index']] = max(vols)
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
        self.mpv = Mpv(null_audio, self.s.get('audio_device', 'auto'), self._mpv_event)
        self.null_audio = null_audio
        self.scan_library()
        self._check_device()
        threading.Thread(target=self._measure_all, daemon=True).start()
        threading.Thread(target=self._poll_loop, daemon=True).start()

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
        if not cue or not re.fullmatch(r'r?[a-d][1-4xy]', str(cue)):
            return None
        p = HERE / 'cues' / f'{cue}.wav'
        return p if p.exists() else None

    def play_tracks(self, idx_list, label=None, cue=None, after_cue=None):
        idx_list = [int(i) for i in idx_list if 0 <= int(i) < 4]
        cue_path, after_path = self._cue_file(cue), self._cue_file(after_cue)
        if not idx_list:
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
            r = self.mpv.cmd({'name': 'loadfile', 'url': str(path), 'flags': 'replace', 'options': {'af': ''}})
            eid = (r.get('data') or {}).get('playlist_entry_id')
            if r.get('error') != 'success' or eid is None:
                return True                                 # a missing cue must never block the test: just skip it
            self.mode = 'test'
            self.cur = {'kind': 'cue', 'rate': path.stem.startswith('r'),
                        'title': 'Voice: please rate now' if path.stem.startswith('r') else 'Voice: step announcement'}
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
        names = self.mpris.names()
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
                            title=info['identity'], sv=sv, running=False, base=0.0, t_run=None)
            if self.mpv.props.get('idle-active') is False:
                self.mpv.fade_stop()
            self.mpris.pause_all_playing(except_name=name)
            if sv.grab():
                sv.scale(0)                    # silent while loading/seeking (only if the stream exists already)
            before = info['trackid']
            if uri:
                self.mpris.call(name, 'OpenUri', 's', uri)
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
            self.cur.update(phase='playing', running=True, t_run=time.monotonic(),
                            title=f'{info["artist"]} – {info["title"]}' if info['title'] else info['identity'])
            if info['title']:
                t['title'] = f'{info["artist"]} – {info["title"]}'
        sv.ramp(0, 1, fade)
        # check that the seek really happened (Position after a moment of playing); retry once if not
        for attempt in (1, 2):
            if cancel.wait(0.6):
                return False
            pos = self.mpris.info(name)['position']
            el = self._elapsed()
            if not (info['can_seek'] and abs(pos - (start + el)) > 3):
                break
            if attempt == 1 and info['trackid']:
                log(f'Track {i + 1}: position {pos:.1f} s instead of {start + el:.1f} s, seeking again')
                with self.lock:
                    if cancel.is_set():
                        return False
                    self.mpris.call(name, 'SetPosition', 'ox', info['trackid'], int((start + el) * 1e6))
            else:
                warn.append(f'{info["identity"]} did not seek: starts at {fmt_time(max(0, pos - el))}')
        self.track_warn[i] = '; '.join(warn)
        if warn:
            log(f'Track {i + 1}:', self.track_warn[i])
        self.store.save()                      # keeps the title on the row
        # timed by the panel: pause when the length is reached
        while not cancel.is_set():
            with self.lock:
                if cancel.is_set():
                    return False
                el = self._elapsed()
                if el >= self.cur['length'] - (fade if sv.orig else 0):   # the fade is part of the length
                    break
            cancel.wait(0.05)
        with self.lock:
            if cancel.is_set():
                return False
            sv.ramp(1, 0, fade)
            self.mpris.call(name, 'Pause')
            sv.restore()
            self.cur['running'] = False
        return True

    def _elapsed(self):
        c = self.cur or {}
        if c.get('kind') != 'stream':
            return 0.0
        return c['base'] + ((time.monotonic() - c['t_run']) if c.get('t_run') else 0.0)

    # ---------- transport (pause, extend, seek, next/prev) ----------
    def pause_toggle(self):
        with self.lock:
            c = self.cur or {}
            if c.get('kind') == 'stream' and c.get('phase') == 'playing':
                if c.get('t_run'):
                    c['base'] = self._elapsed(); c['t_run'] = None
                    self.mpris.call(c['name'], 'Pause')
                else:
                    self.mpris.call(c['name'], 'Play'); c['t_run'] = time.monotonic()
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
            self.mpv.cmd({'name': 'loadfile', 'url': path, 'flags': 'replace', 'options': {'loop-file': 'inf'}})
            self.mode = 'tone'
            self.cur = {'kind': 'tone', 'title': f'Check tone {which} Hz, −12 dBFS (loops until Stop)'}

    # ---------- streaming players (Players tab) ----------
    def player_action(self, name, action):
        if action not in ('PlayPause', 'Play', 'Pause', 'Next', 'Previous', 'Stop'):
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
            now.update(track=c['track'], title=c['title'], elapsed=self._elapsed() if c.get('running') else 0,
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
                    mpv_device=pr.get('audio-device'))

    def close(self):
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
    for k in ('lib_mono', 'lib_match', 'part_d', 'cues', 'auto'):
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
