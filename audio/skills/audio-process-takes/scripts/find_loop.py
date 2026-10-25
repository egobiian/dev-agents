#!/usr/bin/env python3
"""Find where a generated music track loops seamlessly.

Measures the tempo, moves the loop start to the strongest attack near the
guess, then for each bar count looks for the end whose next 6 s of attacks
best match the 6 s after the start.

    python3 scripts/find_loop.py <source.wav> --start 2.5 --bpm 128 --bars 8,16,24,32

A good loop end has a clearly higher match than its neighbours (0.5 or more)
and lies close to the bar grid. A match spread over many offsets means the
music there differs from the loop start, as at a fill. Loop at the end of a
phrase, usually a multiple of 8 bars, and pass the start, the beats and the
measured bpm to loop_music.py.
"""

import argparse

import numpy as np
import soundfile as sf

HOP = 240
FRAME = 1024
MATCH_S = 6.0
START_SEARCH_S = 0.05
END_SEARCH_S = 0.15
TEMPO_RANGE = 0.03
TEMPO_STEP = 0.01


def onset_strength(mono: np.ndarray) -> np.ndarray:
    frames = np.lib.stride_tricks.sliding_window_view(mono, FRAME)[::HOP]
    spectrum = np.abs(np.fft.rfft(frames * np.hanning(FRAME), axis=1))
    return np.maximum(np.diff(np.log1p(spectrum), axis=0), 0.0).sum(axis=1)


# A generative model does not keep the tempo it is asked for exactly: a track asked at 135 bpm can play at 136, so a
# loop cut at 135 gains a beat. The tempo is the one whose beats, over the whole track, land on the most attack: a wrong
# one drifts off the beat within a few bars. Autocorrelation is not enough here: it locks onto sixteenth notes.
def tempo(flux: np.ndarray, fps: float, bpm_guess: float) -> float:
    best_score, best_bpm = -1.0, bpm_guess
    for bpm in np.arange(bpm_guess * (1 - TEMPO_RANGE), bpm_guess * (1 + TEMPO_RANGE), TEMPO_STEP):
        period = 60 * fps / bpm
        beats = np.arange(int((len(flux) - 1) / period)) * period
        phases = np.arange(0.0, period, 0.5)[:, None]
        score = float(flux[np.round(phases + beats).astype(int)].sum(axis=1).max()) / beats.size
        if score > best_score:
            best_score, best_bpm = score, float(bpm)
    return best_bpm


def similarity(a: np.ndarray, b: np.ndarray) -> float:
    a = a - a.mean()
    b = b - b.mean()
    return float(np.dot(a, b) / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-9))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("source")
    parser.add_argument("--start", type=float, required=True, help="where the groove starts, roughly")
    parser.add_argument("--bpm", type=float, required=True, help="the tempo asked for")
    parser.add_argument("--bars", default="8,16,24,32")
    args = parser.parse_args()

    audio, rate = sf.read(args.source, dtype="float32", always_2d=True)
    flux = onset_strength(audio.mean(axis=1))
    fps = rate / HOP
    measured = tempo(flux[int(args.start * fps):], fps, args.bpm)
    print(f"tempo: {measured:.2f} bpm measured, {args.bpm:g} asked; track {len(audio) / rate:.2f} s")

    guess = int(args.start * fps)
    reach = int(START_SEARCH_S * fps)
    start = guess - reach + int(np.argmax(flux[guess - reach:guess + reach]))
    window = int(MATCH_S * fps)
    reference = flux[start:start + window]
    for bars in (int(b) for b in args.bars.split(",")):
        grid = start + round(bars * 4 * 60 / measured * fps)
        candidates = []
        for offset in range(-int(END_SEARCH_S * fps), int(END_SEARCH_S * fps) + 1):
            segment = flux[grid + offset:grid + offset + window]
            if len(segment) == window:
                candidates.append((similarity(reference, segment), offset))
        if not candidates:
            print(f"{bars} bars: past the end of the track")
            continue
        match, offset = max(candidates)
        end = (grid + offset) / fps
        body = end - start / fps
        print(f"{bars} bars: end {end:.3f} s ({offset / fps * 1000:+.0f} ms from the grid), match {match:.2f}, "
              f"loop {body:.3f} s = {bars * 4} beats at {bars * 4 * 60 / body:.3f} bpm")
    print(f"loop start: {start / fps:.3f} s (move it 5 ms earlier so the attack is not cut)")


if __name__ == "__main__":
    main()
