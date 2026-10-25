#!/usr/bin/env python3
"""Cut a generated music WAV into a track that loops seamlessly.

The track keeps everything before the loop start (an intro that plays once)
and ends a whole number of beats after it. Its last 30 ms are blended into the
audio just before the loop start, so the jump back is continuous. Give the
engine the loop start it prints: in Godot, `loop_offset` in the track's
.import file.

    python3 scripts/loop_music.py <source.wav> <target.ogg> --start 2.48 --beats 64 --bpm 128.12 [--seam <seam.ogg>] [--peak -1]

The seam file holds the 8 s before the jump and the 8 s after it, to listen
to the loop point. Find the start and the beats with find_loop.py.
"""

import argparse
import sys

import numpy as np
import soundfile as sf

sys.dont_write_bytecode = True  # leave no __pycache__ in the skill's folder

from encode_music import MUSIC_LEVEL, PEAK_DBFS, write_ogg  # noqa: E402

BLEND_S = 0.03
FADE_IN_S = 0.005
SEAM_S = 8


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--start", type=float, required=True, help="loop start in seconds")
    parser.add_argument("--beats", type=int, required=True, help="length of the loop in beats")
    parser.add_argument("--bpm", type=float, required=True, help="the measured tempo, not the one asked for")
    parser.add_argument("--seam", help="also write the loop point to this file")
    parser.add_argument("--level", type=float, default=MUSIC_LEVEL)
    # One music volume serves every track, so a track louder than the others is written with a lower peak.
    parser.add_argument("--peak", type=float, default=PEAK_DBFS, help="peak level in dBFS")
    args = parser.parse_args()

    audio, rate = sf.read(args.source, dtype="float32", always_2d=True)
    start = round(args.start * rate)
    end = start + round(args.beats * 60 / args.bpm * rate)
    if end > len(audio):
        parser.error(f"the loop ends at {end / rate:.2f} s, after the source ends at {len(audio) / rate:.2f} s")
    track = audio[:end].copy()
    blend = round(BLEND_S * rate)
    ramp = np.linspace(0.0, 1.0, blend, dtype=np.float32)[:, None]
    track[end - blend:end] = audio[end - blend:end] * (1.0 - ramp) + audio[start - blend:start] * ramp
    fade_in = round(FADE_IN_S * rate)
    track[:fade_in] *= np.linspace(0.0, 1.0, fade_in, dtype=np.float32)[:, None]
    track *= (10 ** (args.peak / 20)) / np.abs(track).max()

    write_ogg(args.target, track, rate, args.level)
    if args.seam:
        seam = np.concatenate([track[max(0, end - SEAM_S * rate):end], track[start:start + SEAM_S * rate]])
        write_ogg(args.seam, seam, rate, args.level)
    print(f"{args.target}: {len(track) / rate:.4f} s, loop_offset={start / rate:.4f}, loop {(end - start) / rate:.4f} s")


if __name__ == "__main__":
    main()
