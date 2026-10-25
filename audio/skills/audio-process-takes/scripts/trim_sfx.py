#!/usr/bin/env python3
"""Cut a generated sound effect to the part the game plays.

Keeps start to end, fades in over 5 ms and out over --fade-out, normalises the
peak to -1 dBFS and writes OGG Vorbis.

    python3 scripts/trim_sfx.py <source.ogg> <target.ogg> --start 0 --end 0.6 --fade-out 0.2
"""

import argparse
import sys

import numpy as np
import soundfile as sf

sys.dont_write_bytecode = True  # leave no __pycache__ in the skill's folder

from encode_music import PEAK_DBFS, write_ogg  # noqa: E402

FADE_IN_S = 0.005


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--start", type=float, default=0.0)
    parser.add_argument("--end", type=float, required=True)
    parser.add_argument("--fade-out", type=float, default=0.05)
    args = parser.parse_args()

    audio, rate = sf.read(args.source, dtype="float32", always_2d=True)
    audio = audio[int(args.start * rate):int(args.end * rate)].copy()
    fade_in = int(FADE_IN_S * rate)
    audio[:fade_in] *= np.linspace(0.0, 1.0, fade_in, dtype=np.float32)[:, None]
    fade_out = int(args.fade_out * rate)
    audio[-fade_out:] *= np.linspace(1.0, 0.0, fade_out, dtype=np.float32)[:, None]
    audio *= (10 ** (PEAK_DBFS / 20)) / np.abs(audio).max()
    # Effects are small: the library's default quality is kept.
    write_ogg(args.target, audio, rate, None)
    print(f"{args.target}: {len(audio) / rate:.2f} s")


if __name__ == "__main__":
    main()
