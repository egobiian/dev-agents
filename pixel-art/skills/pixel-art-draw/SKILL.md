---
name: pixel-art-draw
description: Draws and edits small pixel art as text — sprites, tiles, icons, interface pieces and their animation frames — by writing a character grid that a bundled script turns into a PNG, then looking at an enlarged render and correcting it. Use when asked to draw, create, sketch, recolour, fix or animate a sprite, a tile or an icon, to make placeholder art, or to change a few pixels of an existing PNG. Keeps every pixel on the project palette. Suited to art up to about 64 by 64 pixels a frame, not to large illustrations.
compatibility: The bundled scripts need Python 3.8 or later. They use the standard library only.
---

# Draw pixel art as a text grid

One character is one pixel. A grid file lists which colour each character stands for, then gives each frame as rows of characters. `scripts/sprite_grid.py` turns that into a PNG at 1×, and into an enlarged copy to look at. The loop is: write the grid, render, look, correct.

Paths to `scripts/` are relative to this skill's own directory.

The first render is a draft. Expect to go round the loop several times: shapes that seemed right as text look wrong as an image, and only the image counts.

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

- `@palette` names the palette file, relative to the grid file. The script then refuses any colour in the key that is not in it.
- `@key` gives one character per colour: the character, a space, then `#rrggbb` or the word `transparent`. Any visible character except `@` can be used.
- `@frame` starts a frame, with an optional name. Every line after it is one row, one character per pixel. All frames have the same width and height.
- `//` comments are allowed before the first frame only.

Use the same character for the same colour in every grid of a project. The `dump` command names characters after the order of the palette file — `0` for the first colour, `1` for the second — so follow that.

## Procedure

1. **Read the rules.** The style guide and the palette decide the canvas size, the light direction, the outline, how many shades a material gets. With no style guide, look at the art that exists and match it.

2. **Read existing art as text.** This is the fastest way to learn how the project draws:

   ```bash
   python3 scripts/sprite_grid.py dump assets/sprites/hero.png --frame 16x16 --palette art/palette.hex
   python3 scripts/sprite_grid.py preview assets/sprites/hero.png --out /tmp/hero.png
   ```

   The dump shows where the outline breaks, how wide a highlight is, which ramp a material uses. To change existing art, dump it to a file with `--out`, edit that, and render it back.

3. **Plan on the grid before typing rows.** Decide the bounding box of the subject, and the row it stands on. Decide where the light comes from, and which ramp each material uses. For anything symmetrical, decide whether the width is even or odd: an even width has no centre column.

4. **Write the grid**, silhouette first. Fill the shape with flat colour, check it, and only then shade.

5. **Render and look.**

   ```bash
   python3 scripts/sprite_grid.py render potion.grid.txt --out assets/items/potion.png --preview /tmp/potion.png
   ```

   Open the preview. It is enlarged with hard edges, and shows transparency as a grey checkerboard with one check per art pixel. Judge the image: never judge the shape from the text, where characters are taller than they are wide and every sprite looks stretched.

6. **Correct and repeat.** The script reports the line and column of a row that is too short or of a character missing from the key, and writes nothing until the grid is valid. It also prints how many pixels use each colour: a key entry used by two pixels is probably a mistake.

7. **Check it against its background.** Render the preview on a colour the art will be seen against, with `--background 257179`. A sprite that reads well on grey can vanish on the game's own background.

8. **Deliver.** The PNG at 1× goes where the project keeps its art. Never deliver the preview. Keep the grid file only if the project keeps source files, and where it keeps them; otherwise delete it and say so.

## Drawing rules

- **Silhouette first.** If the filled shape alone does not say what the thing is, no shading will.
- **Clusters, not pixels.** Shade in connected patches of colour. A single pixel on its own is noise, unless it is a deliberate detail such as an eye or a glint.
- **One light.** Highlights go on the side the light comes from and shadows on the other, on every part of the sprite. Shading that darkens towards the outline all the way round is pillow shading.
- **Few shades.** Two to four per material, taken from one ramp of the palette, in ramp order. A darker shade is the next colour down the ramp, never a new colour.
- **Clean lines.** A one-pixel line never doubles up at a corner. The steps of a curve change length in order — 1, 1, 2, 3 — never back and forth.
- **No banding.** Do not stack bands of shade that follow each other a pixel apart. Vary where the shade boundaries fall.
- **Hard outer edge.** No lighter fringe pixels to smooth the outside of a sprite. The background is not known, and the fringe shows.
- **Readable beats detailed.** At 16 pixels, three shapes that read are worth more than ten that do not.

## Animation

- All frames go in one grid file, in order. They render as one sheet: a single row, or `--columns N` frames per row.
- Copy the previous frame and change it. Redrawing a frame from scratch loses the volume.
- Change as little as the motion needs. The feet stay on the same row unless the character leaves the ground.
- Look at the frames side by side in the preview. A part that changes size or shade between frames, when that is not the motion, is the usual fault.

## Limits

- A grid holds opaque and fully transparent pixels only. Partly transparent art cannot be dumped or drawn this way.
- Past about 64 by 64 pixels a frame the rows are too long to keep straight. Work in pieces, or say that the job needs an editor and a person.
- The script checks the key against the palette. It does not check the drawing: that is what looking at the preview is for.

`sprite_grid.py --help` lists every option. Exit code 1 means a problem in the grid or the image, and nothing was written. Exit code 2 means a bad argument or an unreadable file.
