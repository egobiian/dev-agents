---
name: godot-pixel-art-setup
description: Configures a Godot 4 project to render pixel art crisply and diagnoses one that does not. Use when starting a pixel-art game, choosing base resolution and stretch settings, or when sprites look blurry, pixels are uneven, tiles show seams, text is smeared, or the picture shimmers or jitters while the camera moves.
---

# Set up a Godot project for pixel art

Pixel art survives only when every art pixel covers the same whole number of screen pixels and is never blended with its neighbours. Godot's defaults do neither: textures are filtered, and a new project scales by whatever fraction fits. Four settings fix that; the rest of this page is about not undoing them.

## 1. Choose the base resolution

The base size is how many art pixels the screen shows. It fixes how large every sprite and tile is drawn and is expensive to change once art exists. Take it from the project's art style guide; if nothing has decided it, ask before picking.

Choose a size whose whole multiples land exactly on the target screens:

| Base size | 1280×720 | 1920×1080 | 2560×1440 | 3840×2160 |
| :- | :- | :- | :- | :- |
| 320×180 | ×4 | ×6 | ×8 | ×12 |
| 640×360 | ×2 | ×3 | ×4 | ×6 |
| 480×270 | no | ×4 | no | ×8 |

Where it says no, the game shows at the next multiple down with black bars.

## 2. Set the four settings

In `project.godot`, adding each key to its existing section and creating a section only if absent (a section written twice breaks the file):

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

- **`stretch/mode="viewport"`** renders at the base size and enlarges the result, so every screen pixel is an art pixel, even on rotated or scaled sprites. Projects created with Godot 4.7+ write `canvas_items` and `expand` in this file: read what is there.
- **`scale_mode="integer"`** rounds the enlargement down to a whole number. Without it a 1366×768 window scales a 640×360 game by 2.13 and pixels come out in two sizes.
- **`default_texture_filter=0`** is Nearest. The default, 1 (Linear), blends neighbours whenever a sprite is not drawn exactly one art pixel to one viewport pixel (fractional position, scaled, rotated, or enlarged by `canvas_items`). A still sprite at a whole position looks fine under Linear, which is how this goes unnoticed.
- **`snap_2d_transforms_to_pixel=true`** rounds the drawn position to a whole pixel; otherwise a sprite at x = 10.5 shimmers as it moves. Do not also enable `snap_2d_vertices_to_pixel`: together they are less smooth still.
- **`aspect`**: `keep` adds black bars on other shapes; `expand` shows more world, so every HUD element must be anchored to its edge.
- **The window override** is only the desktop window size; without it the game opens base-viewport sized. Use a whole multiple.

With integer scaling a window smaller than the base size clips: set `Window.min_size` to the base size. For fullscreen use Exclusive Fullscreen: plain Fullscreen leaves a one-pixel line at the bottom, enough to make integer scaling pick the next multiple down.

## 3. Leave the art alone

- Art is drawn and exported at 1×, one image pixel per art pixel; enlarging happens once, at the window. A sheet exported at 4× and scaled down in the engine is the commonest cause of uneven pixels.
- Keep import defaults: PNG as Lossless, no mipmaps. Never Lossy or VRAM Compressed. Filtering is not an import option in Godot 4.
- Every node's `texture_filter` stays Inherit; a node set to Linear overrides the project default for itself and its children.
- In a shader, `TEXTURE` follows the node's filter; every other sampler needs `filter_nearest` in its hints.

## 4. Keep everything on the grid

- **Scale** is 1, or a whole number where the style allows larger pixels. A fractional scale puts two pixel sizes on screen.
- **Position**: still art sits at whole coordinates. A centred `Sprite2D` with an odd texture width or height lands on a half pixel: turn `centered` off or keep sizes even. Game logic may use fractional positions; snapping only rounds drawing.
- **Camera**: smoothing moves through fractional positions and, with snapping on, visibly roughens: no smoothing, or accept it. Jitter also appears when camera and followed node update in different callbacks: a body moved in `_physics_process` wants a camera with `process_callback` Physics.
- **Tiles**: the TileSet's tile size is the size drawn. Keep Use Texture Padding on in the atlas, or tiles bleed into neighbours.
- **Fonts**: import a pixel font with antialiasing off and subpixel positioning disabled; use only at whole multiples of its design size; never scale a showing control by a fraction.
- **Lights**: Nearest does not pixelate 2D lights and shadows; they stay smooth unless a shader quantises them.

## 5. Check the result

Godot exits 0 from almost every failure, so read the run's output for `ERROR:` or `WARNING:` lines. Then capture a frame with a real renderer (needs a display) and look:

```bash
mkdir -p /tmp/shots
godot --path . res://path/to/scene.tscn --write-movie /tmp/shots/frame.png --fixed-fps 60 --quit-after 30
```

In `viewport` mode frames are at base size: enlarge by a whole factor with nearest-neighbour scaling before judging. Check hard edges, equal pixel size, and that a moving object keeps its shape from frame to frame. If you edited `project.godot` through the editor or `--import`, check its diff for settings the editor dropped or reordered.

## When it looks wrong

| Symptom | Look at |
| :- | :- |
| Everything blurry | `default_texture_filter` still 1 |
| One sprite blurry | Its or a parent's `texture_filter` is Linear; its shader samples without `filter_nearest`; imported Lossy or VRAM Compressed |
| Pixels of different sizes | `scale_mode` not `integer`; fractional node `scale`; art exported enlarged |
| Fullscreen smaller than it could be, in black bars | Fullscreen instead of Exclusive Fullscreen |
| Shimmer or wobble while moving | `snap_2d_transforms_to_pixel` off; camera smoothing on; camera and target update in different callbacks |
| Sprite squashed by one pixel | Centred with an odd size |
| Lines between tiles | Use Texture Padding off, or camera at a fractional position under fractional scaling |
| Smeared or uneven text | Antialiasing or subpixel positioning on, or not a whole multiple of design size |
| Rotated sprite shows smooth, tilted pixels | Stretch mode is `canvas_items`; `viewport` redraws rotation on the art grid |

## The other stretch mode

`canvas_items` draws each sprite at window resolution: sharp with Nearest, smoother movement and scrolling, room for 3D or high-resolution text beside the pixel art. The cost is tilted, uneven pixels under rotation or scaling and no forcing of effects onto the grid. Some games choose it on purpose; record that in the style guide rather than flipping it to fix a symptom.
