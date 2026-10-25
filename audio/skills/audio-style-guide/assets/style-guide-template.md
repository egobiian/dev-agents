# Audio style guide

<One paragraph: what the game sounds like and why, in plain words: the era, the instruments, the mood. No names of other games, films, songs or composers.>

Every rule below can be checked against a file, by measuring it or by listening for a few seconds.

## Music

- **The sound:** <the instruments of every track: leads, bass, drums, pads>.
- **What changes between tracks:** <tempo, key, one colour of a place>. **What never does:** <the instruments>.

| Track | Plays in | Tempo | Key | Loop |
| :- | :- | :- | :- | :- |
| `<title>` | <the title screen> | <90 bpm> | <A minor> | <whole: it ends on its own and starts again> |
| `<level_one>` | <the first level> | <128 bpm asked, measured after generating> | <E minor> | <after an intro, on 16 bars> |
| `<boss>` | <every boss fight> | <160 bpm> | <G minor> | <whole> |

**Prompts:** <the pattern of a music prompt that worked, with the parts that change in italics>. Ask for <about 90 s> for a level, <about a minute> for the rest, with a tempo and a key.

## Effects

- One event, one short sound, clear enough to read under the music.
- Voices: <none | only for ...>.
- **Prompts** name a concrete physical source and say it happens once: <"A short wooden knock on a door, once, then silence.">
- **Length asked:** <about half a second for a hit, a second for a whoosh, two for an impact, three for a sting>. An effect still loud at its end was cut in the middle: trim it with a fade-out.

## Processing

| | Effects | Music |
| :- | :- | :- |
| Generated as | <WAV or OGG> | <WAV> |
| Shipped as | <OGG Vorbis, mono, 48 kHz> | <OGG Vorbis, stereo, 48 kHz> |
| Peak | <-1 dBFS> | <-1 dBFS> |
| Quality | <encoder default> | <compression level 0.9, about 80 kbps> |
| Ends | <5 ms fade in, a fade-out chosen per effect> | <50 ms fades; loops cut on the measured tempo> |

## Levels

- **Music:** every track at an RMS of <-18 dBFS>, played at <-12 dB>. A louder track is written with a lower peak.
- **Effects:** a new effect is set beside one of the same weight in this table, so that both land at the same level in the game.

| Effect | Loudest 100 ms | Volume | In the game |
| :- | :- | :- | :- |
| <`hit`> | <-7.0 dBFS> | <-4 dB> | <-11> |
| <`step`> | <-12.0 dBFS> | <-8 dB> | <-20> |
| <`menu_move`> | <-20.0 dBFS> | <-10 dB> | <-30> |

## Generating

- Effects: <model and version>, <settings>. Music: <model and version>, <settings>. Where they run and the command for a batch: `audio/tool.local.md`, which git ignores.
- Takes per request: <a few seeds for an effect; a couple of prompts with two seeds each for a track>.
- Limits: at most <8 effects or 4 tracks> a batch, one batch at a time, <a minute> between sounds, <five minutes> between batches, nothing heavy at the same time.

## Choosing

Takes are measured first, and the plain failures — noise, a sound cut off, a track with long silences — are left out. The owner listens to the rest beside the sound now in the game, and chooses.

## Files

- Batches, takes and listening pages: `<build/audio/<batch>/>`, which git ignores.
- In the game: `<assets/audio/sfx/<name>.ogg>` and `<assets/audio/music/<name>.ogg>`, at fixed names, so a sound is replaced without touching code.
- `<audio/sources.md>`: a row per file with its prompt, length asked, seed and settings, tempo and key for music, and any cut or loop.

## Change log

| Date | Change | Reason | Existing sounds affected |
| :- | :- | :- | :- |
| <2026-01-15> | <First version> | | |
