---
name: audio-style-guide
description: Writes and maintains the audio style guide of a game — the document that fixes the character of its music and sound effects, the tracks it needs with their tempo, key and loop, the rules for effects, the prompt patterns that work with the generator, the processing, the loudness every sound is matched to, the generation limits and the file conventions — so that sounds made at different times, by models that drift, still sound like one game. Use when starting the sound of a game, when defining or changing its sound direction, when generated sounds do not match each other, or before generating any audio.
---

# Write an audio style guide

Generated audio drifts more than drawn art. Two takes of the same prompt differ, a model plays at a tempo it was not asked for, and an effect made last week is twice as loud as one made today. A style guide holds the decisions that keep them together, and the numbers to check new sounds against.

A rule earns its place when it can be checked by measuring the file or by listening for a few seconds. "Music should feel epic" cannot be checked. "Stage tracks loop after a short intro, on a multiple of 8 bars, at an RMS of -18 dBFS" can.

## Procedure

1. **Listen to what exists through the owner.** If the game has sounds, measure them — length, peak, loudest 100 ms, RMS — and ask the owner what works and what does not. The guide describes them before it prescribes anything.
2. **Find out what cannot be derived.** The mood, the era of the sound, whether anything has a voice, how many tracks the game needs: these come from the owner. Ask. Do not fill a gap with a guess presented as a decision.
3. **Decide in this order**, since each constrains the next:
   1. The character of the sound: the era, the instruments, what the music and the effects share.
   2. The music the game needs: which places get a track, which loop and how.
   3. The rules for effects: one event one sound, length, voices or none.
   4. Processing: format, sample rate, channels, peak, quality.
   5. Levels: the RMS every track matches, and a loudness table for effects.
   6. Generation: the models, the prompt patterns, how many takes per request, the limits on a batch.
   7. Files: where takes are kept, the names and folders the game loads, the record of sources.
4. **Write it from the template** in [assets/style-guide-template.md](assets/style-guide-template.md). A section the game does not need is marked "not used", not deleted.
5. **Keep the prompts that worked.** After each batch, add the pattern of the prompt the owner chose. The guide is where the next request starts.
6. **Put it next to the sounds,** in the repository, as Markdown. If the project has no place for it, `audio/style-guide.md` is a reasonable one.

## What the guide has to decide

**Character**

- The sound in a sentence: the era, the instruments, the mood.
- Whether anything speaks. Voices are the hardest sounds to keep consistent: leave them out unless the game needs them.

**Music**

- A table of tracks: name, tempo, key, and how it loops — whole, or after an intro, on how many bars.
- What changes from one track to another, and what never does. Changing the instruments between tracks breaks cohesion faster than changing the melody.

**Effects**

- One event, one short sound, clear enough to read under the music.
- The length asked for each kind: a hit, a whoosh, an impact, a sting.
- What makes a prompt work with the model. Concrete physical sources work, abstract adjectives give noise.

**Processing**

- Format, sample rate, channels, peak level and encoder quality, for effects and for music.
- How an effect is trimmed, and how a track is looped.

**Levels**

- The RMS every track is matched to.
- A loudness table: each effect's loudest 100 ms, its volume in the game, and the sum, so a new effect is set beside one of the same weight.

**Generation**

- The models, their versions and the settings passed on every call. Where they run and the command that runs them stay out of the guide: they reveal local paths, so they go in `audio/tool.local.md`, which git ignores (the `audio-run-batches` skill sets it up).
- How many takes per request, and how seeds are chosen.
- The limits that protect the machine: takes per batch, rests between sounds and between batches, nothing heavy at the same time.
- Never naming a game, film, song, composer, band or brand in a prompt. Describe it: instruments, tempo, rhythm, mood, era.

**Files**

- Where batches and takes are kept (outside what the game loads, ignored by git), and the fixed names the game loads, so a sound is replaced without touching code.
- The record of every file: prompt, length asked, seed, settings, tempo and key for music, and any cut or loop.

## Changing the guide

A change of level, format or character changes every sound made under it. List the sounds it affects and whether they are to be remade, and add the change to the guide's change log with its reason.

## Common failures

- **Adjectives instead of numbers.** "Punchy, not too loud" where "loudest 100 ms -9 dBFS, volume -4 dB" was available.
- **A tempo trusted.** The tempo asked for is not the tempo played: the loop is measured.
- **Levels by ear in one session.** The next session's ear is different. Measure, and write the number down.
- **Prompts lost.** The prompt that worked lives only in a log that gets deleted. Keep its pattern in the guide.
