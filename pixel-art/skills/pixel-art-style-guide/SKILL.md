---
name: pixel-art-style-guide
description: Writes and maintains a game's pixel-art style guide - resolution, sizes, perspective, palette, light, outlines, animation, file conventions and AI-generation settings. Use when starting a game's art, defining or changing its style, when sprites from different sources do not match, or before anyone draws or generates art.
---

# Write a pixel-art style guide

Pixel art drifts: each sprite looks fine alone and together they look like three games. A style guide makes the decisions once, where everyone who draws will read them. A rule earns its place when a script or a few seconds of looking can check it: "characters are 16 pixels wide, outlined in the darkest colour of their ramp" can be checked; "characters should feel friendly" cannot.

## Procedure

1. **Look at what exists.** Describe the current art before prescribing: measure sprites and tiles, note what they agree on and where they disagree. The disagreements are the decisions to make.
2. **Ask for what cannot be derived**: mood, references, target resolution, scope come from the owner. Never present a guess as a decision.
3. **Decide in dependency order**: base resolution and tile size; perspective; character size relative to a tile; palette; light, outline, shading; animation; file conventions.
4. **Write from** [assets/style-guide-template.md](assets/style-guide-template.md). Fill every section; mark an unneeded one "not used", not deleted.
5. **State each rule checkably**, with its reason in a clause so someone can handle a case it did not foresee.
6. **Make a reference sheet** (one character, tile and object following every rule) beside the guide; compare new art with it.
7. **Put the guide where the art is**, as Markdown, following the project's layout (else `docs/art-style.md`).

## What the guide decides

- **Resolution and grid**: base resolution in art pixels; tile size; sprite sizes (characters, items, icons). One pixel size everywhere, all art at 1x, nothing scaled by a fraction.
- **Perspective**: projection, visible faces, ground line, ground shadows if any.
- **Palette**: file, colour count, ramps and their materials, roles (outline, shared shadow, accents), what is banned (colours outside the file, partial transparency, gradients).
- **Light and shading**: one light direction; shades per material and whether a highlight is its own step; dithering and anti-aliasing inside a sprite (never on the outer edge).
- **Outline**: none, one colour, or a darker shade of what it outlines; thickness and breaks; lightened on the lit side or not; characters outlined and environment not.
- **Shapes and readability**: character height and head size, detail per sprite size, how foreground separates from background.
- **Animation**: frames per action, frame duration, pivot (bottom centre for grounded things, fixed between frames), sheet layout.
- **Tiles**: which repeat seamlessly, variants per surface, transition layout.
- **Interface**: fonts and sizes (whole multiples of design size), icon sizes, how panels and buttons are drawn.
- **Generation** (only for art from an AI generator, which drifts faster): the tool per asset kind; settings on every call (view, outline, shading, detail, canvas); the words every description ends with, in the game's own words, never naming another game, artist or brand; the style-reference asset per kind; how results are brought onto the palette and cleaned; the generation budget per phase (mock-up, pilot, production) and the limit above which the owner is asked; where the record of how each asset was made lives and where the generator's ids live (they identify an account: a local file never committed).
- **Files**: where sources and exported PNGs live and how they are named; which is the source of truth.

## Changing the guide

A change is a change to every sprite drawn under it. List the art the new rule makes wrong, say whether it is redrawn (by when) or a known exception, and date the change in the guide's log with its reason. A rule the art has stopped following is worse than none.

## Common failures

- A mood board instead of rules.
- Rules without numbers ("small outline" for "one pixel").
- A guide nobody can find.
- Decisions made by accident: the first sprite becomes the style. Describe it, decide, write the answer.
