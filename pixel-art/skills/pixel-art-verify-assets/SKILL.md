---
name: pixel-art-verify-assets
description: Pre-commit gate for pixel-art assets. Use before committing sprites, tiles, icons or sheets, or to check, audit or review pixel art. A bundled script checks PNGs against the palette for off-palette colours, partial transparency, enlarged exports and frame sizes, then the art is looked at once enlarged.
compatibility: The bundled scripts need Python 3.8 or later. They use the standard library only.
---

# Verify pixel art before committing

Three gates in order, cheap first. Gate 1 (mechanical) and Gate 2 (looking) always run; Gate 3 when a game can be started. Commit art only when every gate that applies is green. Never report a gate as passing without running it. Paths to `scripts/` are relative to this skill's directory.

## Before the gates

Find the palette file and style guide: they set the palette, tile and frame sizes, and what is allowed (e.g. a glow fading to transparent). With no palette file, say so and report Gate 1 as partly absent; never choose one yourself. If the project keeps sources (`.aseprite`, `.psd`), the PNG is an export: fix the source and re-export.

## Gate 1: mechanical checks

```bash
python3 scripts/audit_sprites.py --palette art/palette.hex --grid 16 assets/sprites
```

Give it the palette, the cell size, and the changed files or directories. It exits 1 on any failure and always ends with a summary:

```text
FAIL assets/sprites/hero.png (48x16, 9 colours)
  palette: 2 colours not in the palette, on 5 pixels
    #fecd75 on 4 pixels, first at (5, 6); nearest palette colour #ffcd75, 0.2 away
    #ff0000 on 1 pixel, first at (9, 2); nearest palette colour #ef7d57, 14.0 away
  alpha: 3 pixels partly transparent
audit_sprites: 12 images checked, 1 failed
```

No `audit_sprites:` line means nothing was checked. Coordinates start at 0 from the top left.

- **`palette`, distance under about 3**: a near miss; replace with the nearest palette colour.
- **`palette`, large distance**: a colour chosen on purpose. Replace it, or the palette changes, which is the palette owner's decision. Never add a colour to make this pass.
- **`palette`, dozens of close colours, usually with `alpha`**: resized, rotated, blurred or JPEG-saved. Do not repair pixel by pixel; re-export from source at 1x, nearest-neighbour.
- **`alpha`**: soft brush or antialiased edge; shows as a fringe. `--allow-alpha` only where the style guide allows; name those files.
- **`scale`**: every art pixel is a 2x2 or larger block, so it was exported enlarged; game art is 1x. Genuinely blocky art (a plain panel) trips it too: `--allow-enlarged`, and say so.
- **`grid`**: width or height not a multiple of the cell; the sheet cannot be cut or the tile will not tile.
- **`colours`** (`--max-colours N`): more colours than the style allows.

The unused-palette-colours line is information; over the whole folder, an unused colour is a removal candidate.

## Gate 2: look once

The script knows colours, not whether the drawing works. Look once per changed asset, never a whole folder. Write enlarged copies:

```bash
mkdir -p /tmp/previews
python3 scripts/audit_sprites.py --palette art/palette.hex --preview /tmp/previews assets/sprites/hero.png
python3 scripts/audit_sprites.py --palette art/palette.hex --preview /tmp/previews --background 257179 assets/sprites/hero.png
```

The first shows a grey checkerboard, one check per art pixel; the second puts the art on a colour it will be seen against. Put an accepted sprite beside the new one. Check the style guide, then: light direction as the rest of the art; outline rule; pillow shading; banding; jaggies (steps like 3, 1, 3, 2); stray pixels; readability at game size and on its background; scale and detail against neighbours.

For an animation, look at frames side by side: equal size, character on the same row, volume steady, no colour only one frame uses.

## Gate 3: in the game

Skip with no engine or when the art is unused. Run the scene that uses it and look at one captured frame at the game's resolution. Blur, uneven pixel sizes or shimmer in motion are engine settings, not art: report them as such.

## Reporting

State which gates ran, which were skipped or absent and why, and what each said. Quote `FAIL` lines. For Gate 2, name the file, frame and place and the rule broken. Never describe a skipped gate as passing, or art as checked when only Gate 1 ran. Passing the gates does not mean the art is good; charm needs a person.
