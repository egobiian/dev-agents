# Art style guide

<One paragraph: what the game looks like and why. Name two or three references, and say what is taken from each.>

Every rule below can be checked against a sprite. Where a rule has a reason, the reason follows it.

## Resolution and grid

| | |
| :- | :- |
| Base resolution | <320×180> |
| Tile size | <16×16> |
| Character size | <16 wide, 24 tall, inside a 16×32 frame> |
| Item and icon size | <16×16> |
| Pixel size | One. All art is drawn and exported at 1×. Nothing in the game is scaled by a fraction. |

## Perspective

- Projection: <side view | top-down | three-quarter top-down | isometric>
- Visible faces: <front only | top and front>
- Ground shadows: <none | a flat ellipse in the shared shadow colour, under anything that stands>

## Palette

- File: `<art/palette.hex>`, <24> colours. No colour outside this file appears in any asset.
- Transparency: a pixel is fully opaque or fully transparent. <Exceptions, if any.>

| Ramp | Colours, dark to light | Used for |
| :- | :- | :- |
| <Warm> | `<1a1c2c 5d275d b13e53 ef7d57 ffcd75>` | <skin, wood, fire> |
| <Cool> | `<1a1c2c 29366f 3b5dc9 41a6f6 73eff7>` | <water, metal, night> |

| Role | Colour | Rule |
| :- | :- | :- |
| Outline | `<1a1c2c>` | <one colour for all outlines> |
| Shared shadow | `<333c57>` | <the darkest shade of every material> |
| Accent | `<ffcd75>` | <only on what the player can pick up> |

## Light and shading

- Light comes from the <top left>, in every asset.
- Shades per material: <three: shadow, base, highlight>.
- Dithering: <not used | only on large flat backgrounds>.
- Anti-aliasing: <not used | inside a sprite only, never on its outer edge>.

## Outline

- <Every character and object has a one-pixel outline in the outline colour. Tiles have none.>
- <Where the outline breaks, or is lightened.>

## Shapes and readability

- Proportions: <a character is three heads tall>.
- Detail: <at 16 pixels, no feature smaller than two pixels except eyes>.
- Foreground and background: <backgrounds use the two darkest steps of each ramp and no outline, so that what moves stands out>.

## Animation

| Action | Frames | Frame time | Loops |
| :- | :- | :- | :- |
| <Idle> | <4> | <200 ms> | <yes> |
| <Walk> | <6> | <100 ms> | <yes> |
| <Attack> | <5> | <80 ms> | <no> |

- Pivot: <bottom centre of the frame>. The feet stay on the same row in every frame of an action on the ground.
- Sheets: <one row per action, frames left to right, no padding>.

## Tiles

- <Ground and wall tiles repeat seamlessly on all four sides.>
- <Each surface has three variants.>
- <How transitions between surfaces are laid out.>

## Interface

- Fonts: <name, drawn at 8 pixels, used at 8 and 16 only>.
- Icons: <16×16, outlined like objects>.
- Panels: <a nine-patch with 4-pixel corners>.

## Files

- Sources: `<art/src/>`, <format>. Exports: `<assets/>`, PNG at 1×.
- Names: `<subject>_<action>.png`, lowercase with underscores.
- The <source file | PNG> is the source of truth. <A PNG is never edited when a source exists.>

## Reference sheet

`<art/reference.png>` — one character, one tile and one object that follow every rule above. New art is compared with it.

## Change log

| Date | Change | Reason | Existing art affected |
| :- | :- | :- | :- |
| <2026-01-15> | <First version> | | |
