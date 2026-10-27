---
name: pixel-art-draw
description: Draws and edits small pixel art as text - a character grid that a bundled script renders to PNG, checked on an enlarged render. Use to draw, sketch, recolour, fix or animate a sprite, tile or icon, make placeholders, or change a few pixels of a PNG. Keeps the project palette; up to about 64 by 64 pixels.
compatibility: The bundled scripts need Python 3.8 or later. They use the standard library only.
---

# Draw pixel art as a text grid

One character is one pixel. A grid file maps characters to colours, then lists each frame as rows. `scripts/sprite_grid.py` renders it to a 1x PNG and an enlarged copy to look at. Loop: write, render, look, correct. Paths to `scripts/` are relative to this skill's directory.

The first render is a draft; shapes that seemed right as text look wrong as an image, and only the image counts.

## The grid file

```text
// A 12x12 potion, lit from the top left.
@palette ../art/palette.hex
@key
. transparent
0 #1a1c2c
2 #b13e53
3 #ef7d57
c #f4f4f4
@frame idle
....0000....
....0cc0....
.....00.....
....0330....
...032230...
..03c22230..
..03222220..
..03222220..
..02222220..
...022220...
....0000....
............
```

- `@palette` names the palette file, relative to the grid file; the script then refuses any key colour not in it.
- `@key`: one line per colour, character, space, then `#rrggbb` or `transparent`. Any visible character except `@`.
- `@frame` starts a frame (optional name); each following line is a row. All frames share one width and height.
- `//` comments only before the first frame.

Use the same character for the same colour in every grid. `dump` names characters by palette order (`0` first colour, `1` second); follow that.

## Procedure

1. **Read the rules**: the style guide and palette set canvas, light, outline and shades per material. Without a guide, match the existing art.
2. **Read existing art as text**:

   ```bash
   python3 scripts/sprite_grid.py dump assets/sprites/hero.png --frame 16x16 --palette art/palette.hex
   python3 scripts/sprite_grid.py preview assets/sprites/hero.png --out /tmp/hero.png
   ```

   To change existing art, dump it to a file with `--out`, edit, and render back.
3. **Plan before typing**: bounding box, standing row, light direction, ramp per material; for symmetry, even or odd width (even has no centre column).
4. **Write the grid**, silhouette first in flat colour, then shade.
5. **Render and look**:

   ```bash
   python3 scripts/sprite_grid.py render potion.grid.txt --out assets/items/potion.png --preview /tmp/potion.png
   ```

   The preview is enlarged with hard edges and a grey checkerboard, one check per art pixel.
6. **Correct and repeat.** The script reports the line and column of a short row or a character missing from the key, and writes nothing until the grid is valid. It prints pixels per colour: a key entry used by two pixels is probably a mistake. These counts are the cheap check; look at the preview once per round.
7. **Check the background**: `--background 257179` previews on a colour the art will be seen against.
8. **Deliver** the 1x PNG where the project keeps its art, never the preview. Keep the grid only if the project keeps sources, where it keeps them; otherwise delete it and say so.

## Drawing rules

- Silhouette first.
- Shade in clusters; a lone pixel is noise unless a deliberate detail.
- One light on every part; darkening towards the outline all round is pillow shading.
- Two to four shades per material from one ramp, in ramp order, never a new colour.
- Curve steps change length in order (1, 1, 2, 3); no doubled pixels at corners; no banding; hard outer edge without fringe pixels.
- Readable beats detailed.

## Animation

- All frames go in one grid file, rendered as one sheet: a single row, or `--columns N` per row.
- Copy the previous frame and change it; keep grounded feet on one row; change only what the motion needs.
- Look at the frames side by side for parts changing size or shade.

## Limits

- Opaque and fully transparent pixels only; partly transparent art cannot be dumped or drawn this way.
- Past about 64 by 64 pixels a frame, work in pieces or say the job needs an editor and a person.
- The script checks the key against the palette, not the drawing.

`sprite_grid.py --help` lists every option. Exit 1: problem in the grid or image, nothing written. Exit 2: bad argument or unreadable file.
