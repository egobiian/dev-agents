---
name: pixel-art-palette
description: Designs, extends and measures a pixel-art colour palette. Use when a game needs a palette, when choosing or adapting one from a palette library, when adding a colour or a ramp, when the art looks muddy, flat or mismatched and the colours need checking for cohesion, or when the real palette has to be recovered from existing sprites. Builds hue-shifted ramps that share their darkest and lightest colours, and measures the result with a bundled script that reports duplicates, near-duplicates, lightness gaps and broken ramps.
compatibility: The bundled scripts need Python 3.8 or later. They use the standard library only.
---

# Build and measure a pixel-art palette

A palette is what makes sprites drawn on different days look like one game. It works when it is small, when its colours are arranged in ramps, and when those ramps share colours with each other. All three can be measured, and `scripts/palette_report.py` measures them.

Paths in this skill are relative to the skill's own directory.

## What holds a palette together

- **Few colours.** Sixteen to thirty-two cover most games. Every colour has a job: a step in a ramp, or a role such as the outline. A colour that only one sprite uses is the first sign of drift.
- **Ramps.** Each material — skin, foliage, stone, metal, water — is drawn with one ramp of three to five colours from dark to light. Lightness rises at every step, by enough to tell neighbours apart.
- **Hue shift.** Along a ramp the hue moves as well as the lightness: usually towards yellow as it gets lighter, and towards blue or purple as it gets darker. A ramp that only changes brightness looks flat and goes muddy in the shadows. Around twenty degrees a step is already a strong shift.
- **Saturation peaks in the middle.** The darkest and the lightest colours of a ramp are less saturated than its midtones. High saturation together with high brightness is the classic mistake: it glows, and nothing sits next to it.
- **Shared ends.** Ramps meet. Several of them start from the same dark colour and end in the same light one, and a midtone of one ramp serves as the shadow of another. This is what cohesion is made of: the same few colours turn up in every sprite.
- **Tinted neutrals.** Greys carry a little of the palette's dominant hue. Pure grey, pure black and pure white look pasted on unless the style is built around them.
- **Reserved colours.** One or two saturated accents are kept for what the player must notice: a pickup, a hazard, an interactive object. Used everywhere, they stop meaning anything.

## Procedure

1. **Read the style guide** if the project has one. It fixes the size of the palette and what it has to cover. If it does not exist yet, list the materials and the moods the game needs before choosing a single colour.

2. **Measure what exists.** When the project already has art, pool its colours:

   ```bash
   python3 scripts/palette_report.py assets/sprites
   ```

   The table shows every colour in use with its pixel count. `NEAR` lines are pairs too close to tell apart: almost always one intended colour that drifted into two. A long tail of colours used by a handful of pixels means the art was resized, rotated or painted with a soft brush.

3. **Start from a ramp, not from a colour.** Pick the midtone of the most important material, then build outwards: darker steps shifting cooler and less saturated, lighter steps shifting warmer and less saturated. Build the next ramp so that it reuses the ends of the first. Starting from a published palette is a legitimate choice. Adopt it whole rather than editing single colours.

4. **Write the palette file** as `.hex`: one colour per line, six hex digits, no `#`. Order it ramp by ramp, dark to light, so that the file reads as the ramps.

5. **Measure it**, naming each ramp from dark to light:

   ```bash
   python3 scripts/palette_report.py art/palette.hex \
     --ramp 1a1c2c,5d275d,b13e53,ef7d57,ffcd75 \
     --ramp 1a1c2c,29366f,3b5dc9,41a6f6,73eff7 \
     --swatch /tmp/palette.png
   ```

   Fix every `DUPLICATE`, `NEAR` and `PROBLEM` line, then run it again. Read the `note:` lines and decide: uneven steps and straight ramps are sometimes intended.

6. **Look at it.** Open the swatch image: the palette, then each ramp on its own row, on mid grey. Each ramp should read as one material going from shadow to light, and no colour should look as though it came from another game.

7. **Try it on art** before declaring it done. A palette that measures well can still lack the one colour the main character needs. Draw or recolour a small sprite and a tile with it.

8. **Record it.** The style guide names the palette file, lists the ramps, and says which colours have roles: the outline, the shared shadow, the accents.

## Reading the report

```text
 #   hex       L      C     h   family
 0  #1a1c2c   23.2    3.1  278   blue
 3  #ef7d57   71.1   15.0   39   orange
```

- **L** is lightness, from 0 for black to 100 for white. It is what a sprite looks like in greyscale, and values are what make a sprite readable. Check that the L values of a ramp are well spread.
- **C** is chroma: 0 is grey, and vivid colours are above 15.
- **h** is the hue angle in degrees. Along a ramp it should travel, not stand still.
- **Distance** is perceptual. About 2 is the smallest difference an eye notices side by side. Colours closer than 3 are reported as near-duplicates; change the limit with `--near`.
- **`lightness: ... largest gap`** shows the widest hole between two neighbouring lightness values in the whole palette. A large gap means some transition has no colour to bridge it.
- **`families`** counts the colours per hue family. A game with forests and no greens shows up here.

The script exits 1 when it finds duplicates, near-duplicates or ramp problems, 0 when it finds none and 2 when it cannot read its input. `--json` prints the same report as JSON. `--help` lists everything.

## Changing a palette that is in use

- The order of the file is part of the palette. Tools refer to colours by position, so add new colours at the end, and never reorder or remove a line while art depends on it.
- Changing a colour changes every sprite that uses it, and the files have to be recoloured to match. Say which art a change touches before making it.
- A sprite that needs a colour the palette lacks is not a reason to add one. First ask whether an existing colour does the job: most of the time it does, and the palette stays small.

## File formats

`palette_report.py` reads `.hex`, GIMP `.gpl`, JASC `.pal`, Paint.NET `.txt` and palette images in `.png`, which covers what palette libraries and pixel-art editors export. Given images or directories instead of one palette file, it pools the colours of every PNG it finds. `--write-hex FILE` saves the result as `.hex`, which also converts between formats.
