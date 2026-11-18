#!/usr/bin/env python3
"""Cut the four listening-test excerpts from the vinyl FLAC rips.

Each excerpt: 35 s, 0.5 s fades, dual mono (left = right = (L+R)/2, so the MiniDSP only needs Input 1),
levelled to the same integrated loudness (TARGET_LUFS, plain gain, no compression), 24-bit 48 kHz FLAC.

    python3 make_excerpts.py <output folder>

To move an excerpt, change its start time below and run again. The music itself is not kept in git.
"""
import json, re, subprocess, sys
from pathlib import Path

VINYL = Path('/mnt/homeserver/media/music/Vinyl')
TARGET_LUFS = -23.0
LENGTH = 35.0
EXCERPTS = [  # (file name, source, start in seconds)
    ('Track1_female_voice.flac', 'Fugees/The Score (1996) [Vinyl]/1-03 - Ready or Not.flac', 60),
    ('Track2_male_voice.flac', 'Michael Bublé/Christmas (2014) [Vinyl]/08 - Have Yourself a Merry Little Christmas.flac', 25),
    ('Track3_bass.flac', 'Miles Davis/Kind of Blue (1987) [Vinyl]/01 - So What.flac', 32),
    ('Track4_full_band.flac', 'Electric Light Orchestra/Out of the Blue (1977) [Vinyl]/1-01 - Turn to Stone.flac', 40),
]
MONO = 'pan=stereo|c0=0.5*c0+0.5*c1|c1=0.5*c0+0.5*c1'


def cut_filter(gain_db=0.0):
    return (f'{MONO},afade=t=in:d=0.5,afade=t=out:st={LENGTH - 0.5}:d=0.5,volume={gain_db:.2f}dB')


def loudness(src, start, gain_db=0.0):
    """Integrated loudness (LUFS) and true peak (dBTP) of the excerpt as it will be written."""
    r = subprocess.run(['ffmpeg', '-hide_banner', '-nostats', '-ss', str(start), '-t', str(LENGTH), '-i', str(src),
                        '-af', cut_filter(gain_db) + ',ebur128=peak=true', '-f', 'null', '-'],
                       capture_output=True, text=True, check=True).stderr
    summary = r[r.rfind('Summary:'):]
    lufs = float(re.search(r'I:\s+(-?[\d.]+) LUFS', summary).group(1))
    peak = float(re.search(r'Peak:\s+(-?[\d.]+|-inf) dBFS', summary).group(1))
    return lufs, peak


def main():
    out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('excerpts')
    out.mkdir(parents=True, exist_ok=True)
    log = []
    for name, rel, start in EXCERPTS:
        src = VINYL / rel
        lufs, _ = loudness(src, start)
        gain = TARGET_LUFS - lufs
        lufs2, peak = loudness(src, start, gain)
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-ss', str(start), '-t', str(LENGTH), '-i', str(src),
                        '-af', cut_filter(gain), '-ar', '48000', '-sample_fmt', 's32', '-bits_per_raw_sample', '24',
                        '-c:a', 'flac', '-map_metadata', '-1', str(out / name)], check=True)
        line = f'{name}: {rel} from {start // 60}:{start % 60:02d}, gain {gain:+.1f} dB -> {lufs2:.1f} LUFS, peak {peak:.1f} dBTP'
        print(line)
        log.append(line)
        if peak > -1.0:
            print('  warning: true peak above -1 dBTP')
    (out / 'EXCERPTS.txt').write_text('\n'.join(log) + '\n')


if __name__ == '__main__':
    main()
