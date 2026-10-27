---
name: audio-style-guide
description: Writes and maintains a game's audio style guide - sound character, tracks with tempo, key and loop, effect rules, prompt patterns, processing, loudness targets, generation limits, file conventions. Use when starting a game's sound, defining or changing its direction, when generated sounds do not match, or before generating audio.
---

# Write an audio style guide

Generated audio drifts: two takes of one prompt differ, a model plays a tempo it was not asked for, and last week's effect is twice as loud as today's. A style guide holds the decisions and the numbers to check new sounds against. A rule earns its place when measuring the file or listening for a few seconds can check it: "stage tracks loop after a short intro, on a multiple of 8 bars, at RMS -18 dBFS" can be checked; "music should feel epic" cannot.

## Procedure

1. **Learn what exists through the owner.** Measure current sounds (length, peak, loudest 100 ms, RMS) and ask what works. Describe before prescribing.
2. **Ask for what cannot be derived**: mood, era, voices, number of tracks. Never present a guess as a decision.
3. **Decide in order**: character; music needed (which places, loops); effect rules (one event one sound, length, voices); processing (format, rate, channels, peak, quality); levels (track RMS, effect loudness table); generation (models, prompt patterns, takes per request, batch limits, budget per phase and the limit above which the owner is asked); files.
4. **Write from** [assets/style-guide-template.md](assets/style-guide-template.md); mark an unneeded section "not used".
5. **Keep the prompts that worked**: after each batch add the pattern the owner chose.
6. **Put it next to the sounds** as Markdown (else `audio/style-guide.md`).

## What the guide decides

- **Character**: the sound in a sentence (era, instruments, mood). Voices are the hardest to keep consistent; leave them out unless needed.
- **Music**: a table of tracks (name, tempo, key, loop whole or after an intro, bars). Keep instruments constant between tracks; varying them breaks cohesion faster than varying melody.
- **Effects**: one event, one short sound that reads under the music; length per kind; concrete physical sources work, abstract adjectives give noise.
- **Processing**: format, sample rate, channels, peak, encoder quality, effect trimming, track looping.
- **Levels**: the RMS all tracks match; a loudness table with each effect's loudest 100 ms, in-game volume, and the sum, so a new effect is set beside one of the same weight.
- **Generation**: models, versions and settings on every call. Where they run and the command stay out (local paths): they go in git-ignored `audio/tool.local.md` (see `audio-run-batches`). Takes per request, seed choice, machine limits (takes per batch, rests, nothing heavy alongside). Never name a game, film, song, composer, band or brand in a prompt; describe instruments, tempo, rhythm, mood, era.
- **Files**: where batches and takes live (outside what the game loads, git-ignored); fixed names the game loads, so sounds are replaced without code changes; a record per file (prompt, length asked, seed, settings, tempo and key, cuts and loops).

## Changing the guide

A change of level, format or character changes every sound made under it. List the affected sounds, say whether they are remade, and log the change with its reason.

## Common failures

- Adjectives instead of numbers ("punchy" for "loudest 100 ms -9 dBFS, volume -4 dB").
- A tempo trusted: measure the loop.
- Levels set by ear in one session: measure and write the number down.
- Prompts lost in a log: keep the pattern in the guide.
