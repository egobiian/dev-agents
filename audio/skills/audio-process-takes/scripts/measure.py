#!/usr/bin/env python3
"""Print what can be seen of a sound without hearing it.

For each file: length, peak, the loudness of its loudest 100 ms (the number to
compare when matching a new effect's volume to an existing one), its RMS level
over the whole file (the number to compare when matching a track's level to
the others), the level of its first and last 0.25 s, and its loudness over
time, every 50 ms for an effect and every second for a track.

    python3 scripts/measure.py <file> [<file> ...]

An effect that stays loud to its last step was cut in the middle of a sound,
and one that stays loud from start to end is often plain noise. A track whose
last step is loud ends abruptly; one that falls to silence ends on its own.
"""

import os
import sys

import numpy as np
import soundfile as sf

EFFECT_MAX_S = 5.0


def db(value: float) -> float:
    return 20 * np.log10(max(value, 1e-9))


def rms(samples: np.ndarray) -> float:
    return float(np.sqrt(np.mean(samples ** 2))) if samples.size else 0.0


def main() -> None:
    for path in sys.argv[1:]:
        audio, rate = sf.read(path, dtype="float32", always_2d=True)
        mono = audio.mean(axis=1)
        seconds = len(mono) / rate
        window = int(0.1 * rate)
        loudest = max((rms(mono[i:i + window]) for i in range(0, max(1, len(mono) - window), window // 4)), default=0.0)
        edge = int(0.25 * rate)
        print(f"{os.path.basename(path)}: {seconds:.2f} s, peak {db(float(np.abs(mono).max())):.1f} dBFS, "
              f"loudest 100 ms {db(loudest):.1f} dBFS, RMS {db(rms(mono)):.1f} dBFS, first 0.25 s {db(rms(mono[:edge])):.0f} dB, last 0.25 s {db(rms(mono[-edge:])):.0f} dB")
        step = int((0.05 if seconds <= EFFECT_MAX_S else 1.0) * rate)
        levels = " ".join(f"{db(rms(mono[i:i + step])):.0f}" for i in range(0, len(mono), step))
        print(f"  dB every {'50 ms' if seconds <= EFFECT_MAX_S else 'second'}: {levels}")


if __name__ == "__main__":
    main()
