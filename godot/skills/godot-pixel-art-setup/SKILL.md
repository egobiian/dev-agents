---
name: godot-pixel-art-setup
description: Configures a Godot 4 project to render pixel art crisply, and diagnoses one that does not. Use when starting a pixel-art game in Godot, when choosing its base resolution and stretch settings, or when sprites look blurry, pixels come out in uneven sizes, tiles show seams, text is smeared, or the picture shimmers or jitters when the camera moves. Covers the base viewport size, stretch mode and integer scaling, the default texture filter, 2D snapping, import settings, fonts, cameras and tile sets.
---

# Set up a Godot project for pixel art

Pixel art survives only when every art pixel covers the same whole number of screen pixels, and is never blended with its neighbours. Godot's defaults do neither: textures are filtered, and a new project scales by whatever fraction fits the window. Four project settings fix that. Everything else on this page is about not undoing them.

## 1. Choose the base resolution

The base size is how many art pixels the screen shows. It is a design decision: it fixes how large every sprite and tile is drawn, and it is expensive to change once art exists. If the project has an art style guide, the resolution comes from there. If nothing has decided it, ask before picking one.

Choose a size whose whole multiples land exactly on the screens the game targets:

| Base size | 1280×720 | 1920×1080 | 2560×1440 | 3840×2160 |
| :- | :- | :- | :- | :- |
| 320×180 | ×4 | ×6 | ×8 | ×12 |
| 640×360 | ×2 | ×3 | ×4 | ×6 |
| 480×270 | no | ×4 | no | ×8 |

Where the table says no, the game is shown at the next multiple down with black bars around it. Most pixel-art games use a base size between 256×224 and 640×480.

## 2. Set the four settings

In `project.godot`, under the sections shown. Add each key to its existing section, and create a section only if it is not there: a section written twice is a broken file.

```ini
[display]

window/size/viewport_width=320
window/size/viewport_height=180
window/size/window_width_override=1280
window/size/window_height_override=720
window/stretch/mode="viewport"
window/stretch/aspect="keep"
window/stretch/scale_mode="integer"

[rendering]

textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
```

- **`window/stretch/mode="viewport"`** renders the whole game at the base size and enlarges the result. Every pixel on screen is then an art pixel, including on a sprite that rotates or scales. Projects created with Godot 4.7 or later start with `canvas_items` and the `expand` aspect written in this file, so do not assume the old defaults: read what is there.
- **`window/stretch/scale_mode="integer"`** rounds the enlargement down to a whole number. Without it a 1366×768 window scales a 640×360 game by 2.13, and the pixels come out in two different sizes.
- **`default_texture_filter=0`** is Nearest. The default, 1, is Linear, which blends every sprite with its neighbours.
- **`snap_2d_transforms_to_pixel=true`** rounds the position at which each node is drawn to a whole pixel. Without it a sprite at x = 10.5 lands between two pixels and shimmers as it moves.
- **`window/stretch/aspect`** decides what happens on a screen of another shape. `keep` shows the base size and adds black bars. `expand` shows more of the world instead, and then every HUD element has to be anchored to its edge of the screen.
- **The window override** is only the size of the window on a desktop. Without it the game opens in a window the size of the base viewport, which on a modern monitor is a postage stamp. Use a whole multiple of the base size.

Do not also enable `2d/snap/snap_2d_vertices_to_pixel`: the two together make movement less smooth still.

With integer scaling a window smaller than the base size clips the picture. Give the window a minimum size equal to the base size (`Window.min_size`). For fullscreen use the Exclusive Fullscreen mode: plain Fullscreen leaves a one-pixel line at the bottom of the screen, which is enough to make integer scaling choose the next multiple down.

## 3. Leave the art alone

- Art is drawn and exported at 1×, one image pixel per art pixel. Enlarging happens once, at the window. A sprite sheet exported at 4× and scaled back down in the engine is the most common source of uneven pixels.
- Import settings stay at their defaults. A PNG imports as Lossless with no mipmaps, which is what pixel art needs. Never Lossy or VRAM Compressed. Filtering is not an import option in Godot 4: it comes from the project setting above.
- The `texture_filter` of every node stays on Inherit. A node set to Linear overrides the project default for itself and its children.
- In a shader, `TEXTURE` follows the node's filter. Every other sampler the shader declares needs `filter_nearest` among its hints.

## 4. Keep everything on the grid

- **Scale.** A sprite's `scale` is 1, or a whole number where the style allows larger pixels. A fractional scale puts two pixel sizes on screen at once.
- **Position.** Art that does not move sits at whole coordinates. A centred `Sprite2D` whose texture has an odd width or height is centred on a half pixel: turn `centered` off, or keep sprite sizes even.
- **Movement.** Game logic may keep fractional positions. Snapping only rounds where things are drawn.
- **Camera.** Camera smoothing moves the camera through fractional positions, and with snapping on that movement is visibly less smooth. Decide per project: no smoothing, or accept the trade. Jitter also appears when the camera and the node it follows are updated in different callbacks: a body moved in `_physics_process` wants a camera whose `process_callback` is Physics.
- **Tiles.** The TileSet's tile size is the size the tiles were drawn at. Leave Use Texture Padding on in the atlas: it is what stops a tile bleeding into its neighbour.
- **Fonts.** Import a pixel font with antialiasing off and subpixel positioning disabled, and use it only at whole multiples of the size it was drawn at. A control that shows it is never scaled by a fraction.
- **Lights.** Nearest filtering does not pixelate 2D lights and shadows. They stay smooth unless a shader quantises them.

## 5. Check the result

Run a scene and capture a frame with a real renderer, then look at it:

```bash
mkdir -p /tmp/shots
godot --path . res://path/to/scene.tscn --write-movie /tmp/shots/frame.png --fixed-fps 60 --quit-after 30
```

This opens a window, so it needs a display. In the `viewport` stretch mode the frames are written at the base size, one image pixel per art pixel: enlarge one by a whole factor with nearest-neighbour scaling before judging it. Check that edges are hard, that every art pixel is the same size, and that a moving object does not change shape from frame to frame.

Godot exits 0 from almost every failure. Read the output of the run for lines that start with `ERROR:` or `WARNING:` rather than trusting the exit code.

## When it looks wrong

| Symptom | Look at |
| :- | :- |
| Everything is blurry | `default_texture_filter` is still 1 |
| One sprite is blurry | Its `texture_filter`, or a parent's, is set to Linear. Its material's shader samples without `filter_nearest`. It was imported Lossy or VRAM Compressed |
| Pixels of different sizes | `scale_mode` is not `integer`. A node has a fractional `scale`. The art was exported enlarged |
| Fullscreen shows the game smaller than it could, inside black bars | The window mode is Fullscreen rather than Exclusive Fullscreen |
| Shimmer or wobble while moving | `snap_2d_transforms_to_pixel` is off. Camera smoothing is on. The camera and its target update in different callbacks |
| A sprite looks squashed by one pixel | It is centred and has an odd size |
| Lines between tiles | Use Texture Padding is off in the atlas, or the camera sits at a fractional position under fractional scaling |
| Smeared or uneven text | The font has antialiasing or subpixel positioning on, or is used at a size that is not a whole multiple of its design size |
| A rotated sprite shows smooth, tilted pixels | The stretch mode is `canvas_items`, which draws at the window's resolution. `viewport` redraws the rotation on the art grid |

## The other stretch mode

`canvas_items` draws each sprite at the window's resolution. Sprites stay sharp with the Nearest filter, movement and camera scrolling are smoother because positions are no longer limited to art pixels, and a 3D view or high-resolution text can sit beside the pixel art. The cost is that rotation and scaling show tilted and uneven pixels, and nothing forces an effect onto the grid. Some games choose it on purpose. It is a style decision to record in the project's style guide, not a setting to flip to fix a symptom.
