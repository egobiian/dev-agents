---
name: audio-process-takes
description: Turns generated sound-effect and music takes into game files. Scripts measure takes, build a listening page, trim effects, encode OGG, find seamless loop points despite tempo drift and cut intro plus loop. Use after generating audio, when choosing between takes, or when a sound is cut off, too loud or must loop.
compatibility: The bundled scripts need Python 3.10 or later with numpy and soundfile 0.12 or later (`pip install numpy soundfile`).
---

# Process generated audio takes

A model returns takes, not game files: some are noise, cut mid-sound, or off tempo. This skill rules out failures by measuring, lets the owner choose by ear, and finishes the chosen take. You cannot hear; numbers show where a sound is loud and where it stops, enough to rule out plain failures. Choosing between working takes is always the owner's call, and the owner listens once per sound, not to a whole folder.

Paths to `scripts/` are relative to this skill's directory. Run the scripts with the Python that has numpy and soundfile (the one named in the project's local audio notes). Keep takes, pages and working files in a git-ignored scratch folder, never beside the game's assets.

## 1. Measure every take (cheap first)

```bash
python3 scripts/measure.py <take> [<take> ...]
```

Per file: length, peak, loudest 100 ms, RMS, level of the first and last 0.25 s, and loudness over time (every 50 ms for an effect, every second for a track). Leave out, and say why:

- an effect still loud at its last step (cut mid-sound);
- an effect loud from start to end (often noise);
- a track with long silences, or abrupt starts or ends it should not have.

## 2. Let the owner listen

```bash
python3 scripts/review_page.py <scratch>/review.html \
  --group "Door knock (pick one)" <take> <take> <take> \
  --group "Footstep" <take> <take>
```

Each group is one sound to choose; add the sound the game plays now for comparison. Rows show name, length and, from a generator JSON sidecar (`<file>.json`, or `<name>.wav.json` for a track encoded from WAV), seed and prompt. The page links files by relative path: keep it beside them. Open it (`open` on macOS, `xdg-open` on Linux), say in one line per take what its shape shows, and wait for the choice.

## 3. Finish an effect

```bash
python3 scripts/trim_sfx.py <take> <target.ogg> --start 0 --end 0.6 --fade-out 0.2
```

Keeps `--start` to `--end`, fades in 5 ms and out over `--fade-out`, normalises the peak to -1 dBFS, writes OGG Vorbis. Choose the end from the measurement, where the sound has fallen away, with a fade long enough not to click.

## 4. Finish a track that plays whole

```bash
python3 scripts/encode_music.py <take.wav> <target.ogg> [--level 0.9]
```

Trims trailing near-silence, fades both ends 50 ms, normalises the peak to -1 dBFS, writes stereo OGG Vorbis. `--level` is libsndfile's compression level (0.9 is Vorbis quality 0.1, about 80 kbps, a 90 s track under a megabyte). Also use it for small OGG copies of long WAVs for the listening page. Generate music as WAV and encode once, at the end: each lossy re-encode costs quality.

## 5. Loop a track after an intro

The model does not hold the tempo asked, so a loop cut at that tempo gains or loses part of a beat and stutters. Measure first:

```bash
python3 scripts/find_loop.py <take.wav> --start 2.5 --bpm 128 --bars 8,16,24,32
```

`--start` is roughly where the groove begins, `--bpm` the tempo asked. It prints the measured tempo, then for each bar count the loop end whose next 6 s best match the 6 s after the start, and the loop start moved onto the strongest attack. A good end matches clearly better than the other counts (0.5 or more) and sits near the bar grid; a low match means different music there, as at a fill. Loop on a phrase, usually a multiple of 8 bars.

```bash
python3 scripts/loop_music.py <take.wav> <target.ogg> --start 2.48 --beats 64 --bpm 128.12 --seam <scratch>/seam.ogg [--peak -1]
```

Pass the loop start 5 ms earlier than printed (so the attack is not cut), the loop length in beats, and the **measured** tempo. The track keeps its intro, ends a whole number of beats after the loop start, and blends its last 30 ms into the audio before the start. It prints the `loop_offset` for the engine. The seam file holds 8 s before and 8 s after the jump: give it to the owner to check by ear.

In Godot, set `loop=true` and `loop_offset` in the track's `.import`, delete its files under `.godot/imported/`, and import again; Godot does not reimport just because `.import` changed.

## 6. Match the level

Measure the finished file with `measure.py`.

- **Music**: one music volume usually serves all tracks, so match RMS. A louder track gets a lower peak: `loop_music.py --peak -2.5`.
- **Effects**: compare the loudest 100 ms with an effect of the same weight already in the game and set volume so they land equal. Volume goes in the project's data, never as a code literal.

## Report

Takes measured and those left out with reasons, the owner's choice, files written with length, loop start and length, and levels measured, in under 150 words.
