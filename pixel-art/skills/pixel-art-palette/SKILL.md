---
name: pixel-art-palette
description: Designs, extends and measures a pixel-art palette. Use when a game needs a palette, to adapt one from a library, add a colour or ramp, fix muddy, flat or mismatched colours, or recover the palette from sprites. Builds hue-shifted ramps; a bundled script reports duplicates, near-duplicates, lightness gaps and broken ramps.
compatibility: The bundled scripts need Python 3.8 or later. They use the standard library only.
---

# Build and measure a pixel-art palette

A palette makes sprites drawn on different days look like one game. It works when it is small, arranged in ramps, and the ramps share colours. `scripts/palette_report.py` measures all three. Paths are relative to this skill's directory.

## What holds a palette together

- **Few colours**, each with a job: a ramp step or a role such as the outline. A colour used by one sprite signals drift.
- **Ramps**: one of three to five colours per material, lightness rising at every step enough to tell neighbours apart.
- **Hue shift** along a ramp (usually warmer when lighter, cooler or more purple when darker); brightness-only ramps go flat and muddy. About twenty degrees a step is strong.
- **Saturation peaks in the middle**; the ends are less saturated. High saturation with high brightness glows and fits nothing.
- **Shared ends**: ramps start from the same dark and end in the same light, and a midtone of one serves as another's shadow.
- **Tinted neutrals**: greys carry a little of the dominant hue; pure grey, black and white look pasted on.
- **Reserved accents** for what the player must notice.

## Procedure

1. **Read the style guide** if there is one (palette size, coverage). Otherwise list the materials and moods first.
2. **Measure what exists** by pooling the colours of current art:

   ```bash
   python3 scripts/palette_report.py assets/sprites
   ```

   `NEAR` pairs are one intended colour that drifted into two. A long tail of rarely used colours means the art was resized, rotated or painted with a soft brush.
3. **Start from a ramp, not a colour**: the midtone of the key material, then darker steps cooler and less saturated, lighter steps warmer and less saturated. Reuse the ends in the next ramp. A published palette is legitimate; adopt it whole.
4. **Write the file** as `.hex`: one colour per line, six hex digits, no `#`, ramp by ramp, dark to light.
5. **Measure it**, naming each ramp dark to light:

   ```bash
   python3 scripts/palette_report.py art/palette.hex \
     --ramp 1a1c2c,5d275d,b13e53,ef7d57,ffcd75 \
     --ramp 1a1c2c,29366f,3b5dc9,41a6f6,73eff7 \
     --swatch /tmp/palette.png
   ```

   Fix every `DUPLICATE`, `NEAR` and `PROBLEM` line and rerun. Decide about `note:` lines; uneven steps and straight ramps are sometimes intended.
6. **Look at the swatch once**: each ramp should read as one material from shadow to light.
7. **Try it on art**: recolour a small sprite and a tile; a palette that measures well can still lack a colour.
8. **Record it** in the style guide: file, ramps, and roles (outline, shared shadow, accents).

## Reading the report

- **L** lightness 0-100 (the greyscale look; check ramps are well spread). **C** chroma (0 grey, vivid above 15). **h** hue angle, which should travel along a ramp.
- **Distance** is perceptual; about 2 is the smallest noticeable difference. Under 3 is a near-duplicate (change with `--near`).
- **`lightness: ... largest gap`** is the widest hole between neighbouring lightness values: a transition with no bridging colour.
- **`families`** counts colours per hue family.

Exit 1: duplicates, near-duplicates or ramp problems. 0: none. 2: unreadable input. `--json` prints JSON; `--help` lists options.

## Changing a palette in use

- File order is part of the palette (tools refer to colours by position): add at the end, never reorder or remove while art depends on it.
- Changing a colour changes every sprite using it; say which art a change touches first.
- A sprite lacking a colour is not a reason to add one; first check whether an existing colour does the job.

## File formats

`palette_report.py` reads `.hex`, GIMP `.gpl`, JASC `.pal`, Paint.NET `.txt` and palette `.png`. Given images or directories, it pools colours of every PNG. `--write-hex FILE` saves `.hex`, also converting between formats.
