---
name: audio-process-takes
description: Turns generated sound effects and music takes into the files a game plays, without anyone but the owner listening. Bundled scripts measure each take to rule out failures and to match levels, build a page to listen to the takes side by side, trim and fade an effect, normalise and encode a track to OGG Vorbis, find where a generated track loops seamlessly despite the tempo the model drifted to, and cut it into an intro plus a loop with a seam file to check by ear. Use after generating sounds or music with an AI model, when choosing between takes, when a sound is cut off or too loud, or when a track has to loop.
compatibility: The bundled scripts need Python 3.10 or later with numpy and soundfile 0.12 or later (`pip install numpy soundfile`).
---

# Process generated audio takes

A generative audio model returns takes, not game files. Some are noise, some are cut in the middle of the sound, some drift off the tempo they were asked for. This skill rules out the failures by measuring them, lets the owner choose by ear, and turns the chosen take into a file the game plays.

You cannot hear the takes. The numbers show the shape of a sound — where it is loud, where it stops — and that is enough to rule out the plain failures. Choosing between takes that work is the owner's call, always.

Paths to `scripts/` are relative to this skill's directory. Run the scripts with the Python that has numpy and soundfile installed: the one the project's local audio notes name, if it keeps them. Keep takes, pages and working files in a scratch folder the repository ignores, never next to the game's assets.

## 1. Measure every take

```bash
python3 scripts/measure.py <take> [<take> ...]
```

For each file: length, peak, the loudness of its loudest 100 ms, its RMS over the whole file, the level of its first and last 0.25 s, and its loudness over time, every 50 ms for an effect and every second for a track.

Leave out, and say why:

- an effect that stays loud to its last step: it was cut in the middle of the sound;
- an effect that stays loud from start to end: often plain noise;
- a track with long silences in it, or one that starts or ends abruptly when it should not.

## 2. Let the owner listen

```bash
python3 scripts/review_page.py <scratch>/review.html \
  --group "Door knock (pick one)" <take> <take> <take> \
  --group "Footstep" <take> <take>
```

Each group is one sound to choose. Put the sound the game plays now beside the takes, so the owner compares with what exists. Each row shows the name, the length and, when the generator wrote a JSON sidecar beside the file (`<file>.json`, or `<name>.wav.json` for a track encoded from a WAV), its seed and prompt. The page links the files by relative path: keep it beside them.

Open it for the owner (`open` on macOS, `xdg-open` on Linux) and say in one line per take what its shape shows. Then wait for their choice.

## 3. Finish an effect

```bash
python3 scripts/trim_sfx.py <take> <target.ogg> --start 0 --end 0.6 --fade-out 0.2
```

Keeps `--start` to `--end`, fades in over 5 ms and out over `--fade-out`, normalises the peak to -1 dBFS and writes OGG Vorbis. Choose the end from the measurement: where the sound has fallen away, with a fade-out long enough that the tail does not click.

## 4. Finish a track that plays whole

```bash
python3 scripts/encode_music.py <take.wav> <target.ogg> [--level 0.9]
```

Trims trailing near-silence, fades both ends over 50 ms, normalises the peak to -1 dBFS and writes stereo OGG Vorbis. `--level` is libsndfile's compression level: 0.9 is Vorbis quality 0.1, about 80 kbps, which keeps a 90 s track under a megabyte. A track that ends on its own and starts again from the top loops whole this way. Also use it to make small OGG copies of long WAV takes for the listening page.

Generate music as WAV and encode once, at the end: every lossy re-encode costs quality.

## 5. Loop a track after an intro

A model does not keep the tempo it is asked for exactly. A loop cut at the asked tempo gains or loses part of a beat, and the seam stutters. Measure first:

```bash
python3 scripts/find_loop.py <take.wav> --start 2.5 --bpm 128 --bars 8,16,24,32
```

`--start` is roughly where the groove begins after the intro, `--bpm` the tempo asked for. It prints the measured tempo, then for each bar count the loop end whose next 6 s best match the 6 s after the start, and the loop start moved onto the strongest attack. A good end has a clearly higher match than the other counts (0.5 or more) and sits close to the bar grid. A low match means the music there differs from the start, as at a fill. Loop on a phrase, usually a multiple of 8 bars.

```bash
python3 scripts/loop_music.py <take.wav> <target.ogg> --start 2.48 --beats 64 --bpm 128.12 --seam <scratch>/seam.ogg [--peak -1]
```

Pass the loop start moved 5 ms earlier than printed, so the attack is not cut, the loop length in beats, and the **measured** tempo. The track keeps its intro, ends a whole number of beats after the loop start, and blends its last 30 ms into the audio before the start so the jump back is continuous. It prints the `loop_offset` to give the engine. The seam file holds 8 s before the jump and 8 s after: give it to the owner to check the loop by ear.

In Godot, set `loop=true` and `loop_offset` in the track's `.import` file, delete its files under `.godot/imported/` and import again: Godot does not reimport a file only because its `.import` changed.

## 6. Match the level

Measure the finished file with `measure.py`.

- **Music:** one music volume usually serves every track, so tracks match by RMS. A track louder than the others is written with a lower peak: `loop_music.py --peak -2.5`.
- **Effects:** compare the loudest 100 ms with an effect of the same weight already in the game, and set the new one's volume so that the two land at the same level in the game. The volume goes in the project's data, never as a literal in code.

## Report

The takes measured and the ones left out with the reason, the take the owner chose, the files written with their length, the loop start and length of any loop, and the levels measured.
