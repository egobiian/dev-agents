# Pixel art

Agents and skills for the pixel art of a game: its style, its palette, and the checks that keep sprites drawn at different times looking like one game. Names in this section start with `pixel-art-`.

Nothing here depends on a game engine. For rendering pixel art crisply in Godot, see [godot-pixel-art-setup](../godot/skills/godot-pixel-art-setup/SKILL.md) in the [godot](../godot/README.md) section.

## Agents

| Agent | What it does |
| :- | :- |
| [pixel-art-director](agents/pixel-art-director.md) | Defines the style guide and the palette, derives them from the art that exists, and says which art a change invalidates |
| [pixel-art-artist](agents/pixel-art-artist.md) | Draws and edits sprites, tiles and icons as text grids rendered to PNG, inside the style guide and the palette |
| [pixel-art-reviewer](agents/pixel-art-reviewer.md) | Read-only review of assets against the palette and the style guide, by measurement and by looking |

The three are designed to be used together: the director decides the rules, the artist draws inside them, and the reviewer checks the result against them. Each agent preloads the skills it works with through the `skills` field of its frontmatter, so copy the whole section rather than single files.

## Skills

| Skill | What it does |
| :- | :- |
| [pixel-art-style-guide](skills/pixel-art-style-guide/SKILL.md) | Writes the style guide: resolution, perspective, palette, light, outline, animation and file rules, each one checkable, from a template |
| [pixel-art-palette](skills/pixel-art-palette/SKILL.md) | Builds a palette out of hue-shifted ramps and measures it: duplicates, near-duplicates, lightness gaps, broken ramps |
| [pixel-art-draw](skills/pixel-art-draw/SKILL.md) | Draws small pixel art as a text grid that a script renders to PNG, and turns an existing PNG back into a grid to edit |
| [pixel-art-verify-assets](skills/pixel-art-verify-assets/SKILL.md) | Pre-commit gate for art: off-palette colours, partial transparency, enlarged exports and frame sizes, then looking at it enlarged |

The scripts need Python 3.8 or later and nothing else: they read and write PNG with the standard library. `pixel-art-palette`, `pixel-art-draw` and `pixel-art-verify-assets` each carry an identical copy of `scripts/pixelkit.py`, so that a skill still works when it is copied on its own.
