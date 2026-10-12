---
name: pixel-art-verify-assets
description: Pre-commit gate for pixel-art assets. Use before every commit that adds or changes sprites, tiles, icons or sprite sheets, or when asked to check, audit or review pixel art for consistency. Runs a bundled script that checks every PNG against the project palette and flags off-palette colours, partly transparent pixels, art exported enlarged and frame sizes off the grid, then has the art looked at enlarged, on the backgrounds it will be seen against, for what a script cannot judge. Reports which gates ran and what they said.
compatibility: The bundled scripts need Python 3.8 or later. They use the standard library only.
---

# Verify pixel art before committing

Three gates, in order. Gate 1 is mechanical and always runs. Gate 2 is looking, and always runs. Gate 3 runs when the art is used by a game that can be started. Art is committed only when every gate that applies is green. Never report a gate as passing without having run it.

Paths to `scripts/` are relative to this skill's own directory.

## Before the gates

Find the project's rules: its palette file, and its style guide if it has one. They say which palette applies, the tile and frame sizes, and what is allowed — a glow that fades to transparent, for instance. Without a palette file there is nothing to check colours against: say so, and report Gate 1 as partly absent rather than choosing a palette yourself.

If the project keeps source files — `.aseprite`, `.psd` — the PNG is an export. A defect is fixed in the source and exported again. A fix made to the PNG alone is undone by the next export.

## Gate 1 — The mechanical checks

```bash
python3 scripts/audit_sprites.py --palette art/palette.hex --grid 16 assets/sprites
```

Give it the palette, the cell size the art is drawn to, and the files or directories that changed. It exits 1 when any image fails, and its last line is always the summary:

```text
FAIL assets/sprites/hero.png (48x16, 9 colours)
  palette: 2 colours not in the palette, on 5 pixels
    #fecd75 on 4 pixels, first at (5, 6); nearest palette colour #ffcd75, 0.2 away
    #ff0000 on 1 pixel, first at (9, 2); nearest palette colour #ef7d57, 14.0 away
  alpha: 3 pixels partly transparent
audit_sprites: 12 images checked, 1 failed
```

A run without the `audit_sprites:` line checked nothing. Coordinates count from the top left corner, starting at 0.

What each failure means, and what to do about it:

- **`palette`, a distance under about 3.** A near miss: the right colour picked by eye, or carried over from another file. Replace it with the nearest palette colour.
- **`palette`, a large distance.** A colour somebody chose on purpose that the palette does not have. Either it is replaced with a palette colour, or the palette changes — and that is a decision for whoever owns the palette. Never add a colour to the palette file to make this gate pass.
- **`palette`, dozens of colours at small distances, usually with `alpha` as well.** The image was resized, rotated or blurred with smoothing on, or was saved as JPEG at some point. Do not repair it pixel by pixel. Export it again from the source, at 1×, with nearest-neighbour settings.
- **`alpha`.** Partly transparent pixels come from a soft brush, a soft eraser or an antialiased edge. Against a background nobody chose, they show as a fringe. Pass `--allow-alpha` only for art the style guide allows it on, and name those files in the report.
- **`scale`.** Every art pixel is a block of 2×2 or more: the file was exported enlarged. Game art is stored at 1×, and the game does the enlarging. Art that really is made of large flat blocks — a plain panel, a two-colour bar — trips this too: pass `--allow-enlarged` for those files, and say so.
- **`grid`.** The width or height is not a multiple of the cell. A sheet like that cannot be cut into frames, and a tile like that does not tile.
- **`colours`**, with `--max-colours N`. More colours in one image than the style allows.

The line about unused palette colours is information, not a failure. Over the whole art folder, a colour nothing uses is a candidate for removal.

## Gate 2 — Look at it

The script knows which colours are in a file, not whether the drawing is any good. Write enlarged copies and open them:

```bash
mkdir -p /tmp/previews
python3 scripts/audit_sprites.py --palette art/palette.hex --preview /tmp/previews assets/sprites/hero.png
python3 scripts/audit_sprites.py --palette art/palette.hex --preview /tmp/previews --background 257179 assets/sprites/hero.png
```

The first shows transparent pixels as a grey checkerboard, one check per art pixel, which makes it possible to count. The second puts the art on a colour it will actually be seen against. Do both, and put a sprite the project already accepts next to the new one.

Check against the style guide first, then against the craft:

- **Light.** Highlights and shadows fall on the same sides as in the rest of the art.
- **Outline.** It follows the project's rule: its colour, its thickness, where it breaks.
- **Pillow shading.** Shading that follows the outline inwards, darkest at the edge all the way round, means no light direction was chosen.
- **Banding.** Bands of shade that run parallel to the outline or to each other, each one a pixel inside the last. They flatten the form and show the grid.
- **Jaggies.** A line or a curve whose steps do not change length in order — runs of 3, 1, 3, 2 pixels — reads as a kink.
- **Stray pixels.** Single pixels that belong to no cluster are noise, unless they are a deliberate detail such as an eye or a glint.
- **Readability.** The silhouette says what the thing is. It still does at the size the game shows it, and against the background it stands on.
- **Scale and proportion.** It is the same size, and has the same level of detail, as the sprites that will stand next to it.

For an animation, look at the frames side by side and in order:

- Every frame has the same size, and the character stands on the same row in each.
- Volume holds from frame to frame: nothing grows, shrinks or changes shade unless that is the motion.
- No frame introduces a colour the others do not use.

## Gate 3 — In the game

Skip when no engine is available, or when the art is not yet used anywhere.

Art is finished when it looks right where the player sees it: at the game's resolution, enlarged by the game, on the game's backgrounds, next to the game's other sprites. Run the scene that uses it and look at a captured frame. Blur, uneven pixel sizes or a shimmer while moving are problems in the engine's settings rather than in the art. Report them as such, and leave the art alone.

## Reporting

State which gates ran, which were skipped or absent and why, and what each said. Quote the script's `FAIL` lines. For what you saw in Gate 2, name the file, the frame and the place, and say which rule of the style guide it breaks, or which of the points above. Never describe a skipped gate as passing, and never describe art as checked when only Gate 1 ran.

Passing the gates is not the same as the art being good. The gates catch what breaks cohesion; whether a sprite has charm still needs a person.
