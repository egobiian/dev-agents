#!/usr/bin/env python3
"""Turn a generated music WAV into the game's OGG.

Trims trailing near-silence, gives both ends a 50 ms fade, normalises the peak
to -1 dBFS and writes stereo OGG Vorbis at the music quality.

    python3 scripts/encode_music.py <source.wav> <target.ogg> [--level 0.9]
"""

import argparse

import numpy as np
import soundfile as sf

SILENCE_DBFS = -50.0
FADE_S = 0.05
PEAK_DBFS = -1.0
# libsndfile's compression level: 0.9 is Vorbis quality 0.1, about 80 kbps.
MUSIC_LEVEL = 0.9
# libsndfile's Vorbis encoder fails on very large writes, so audio goes in blocks.
BLOCK_FRAMES = 8192


def write_ogg(path: str, audio: np.ndarray, rate: int, level: float | None) -> None:
    options = {} if level is None else {"compression_level": level}
    with sf.SoundFile(path, "w", samplerate=rate, channels=audio.shape[1], format="OGG", subtype="VORBIS", **options) as out:
        for start in range(0, len(audio), BLOCK_FRAMES):
            out.write(audio[start:start + BLOCK_FRAMES])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--level", type=float, default=MUSIC_LEVEL)
    args = parser.parse_args()

    audio, rate = sf.read(args.source, dtype="float32", always_2d=True)
    loud = np.nonzero(np.abs(audio).max(axis=1) > 10 ** (SILENCE_DBFS / 20))[0]
    if loud.size:
        audio = audio[:loud[-1] + 1]
    fade = int(FADE_S * rate)
    ramp = np.linspace(0.0, 1.0, fade, dtype=np.float32)[:, None]
    audio[:fade] *= ramp
    audio[-fade:] *= ramp[::-1]
    audio *= (10 ** (PEAK_DBFS / 20)) / np.abs(audio).max()
    write_ogg(args.target, audio, rate, args.level)
    print(f"{args.target}: {len(audio) / rate:.2f} s")


if __name__ == "__main__":
    main()
