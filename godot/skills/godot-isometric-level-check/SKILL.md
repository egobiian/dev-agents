---
name: godot-isometric-level-check
description: Proves a level seen from above in Godot 4, isometric or top-down, can be cleared. A bundled script flood-fills the floor from the spawn and fails on enemies or required nodes the player cannot reach, floor outside the camera limits, and missing or stale navigation; it can draw a map. Use after changing a level, a prop's collision or the player's size.
compatibility: Needs the Godot 4 editor binary. The bundled script needs Godot 4.4 or later.
---

# Check that a level can be cleared

Walking a level proves one route. [scripts/level_check.gd](scripts/level_check.gd) flood-fills every floor position the player's collision shape can stand on, counting walls, the collision of props and any passage narrower than the player as solid, then reads the level against that. Square and diamond cells are both read from the tile set's `tile_shape`. `scripts/` is relative to this skill's directory; give Godot the absolute path.

## Run it

```bash
mkdir -p /tmp/level-maps
godot --headless --path . --script /abs/path/to/scripts/level_check.gd -- \
  res://levels/dungeon.tscn \
  --player res://player/player.tscn \
  --required-group triggers,exits \
  --image /tmp/level-maps/dungeon.png 2>&1
```

Run it on every level a change can affect; a change to the player's shape, a prop's collision or the tile set affects all of them.

| Option | What it gives |
| :- | :- |
| `--spawn-group` | The spawn marker, at the player's feet. Default `player_spawn` |
| `--enemy-group` | Enemies, at their feet. Default `enemies` |
| `--required-group a,b` | Groups of nodes the player must reach: trigger, exit, objective, chest. Default `required` |
| `--solid-group a,b` | Groups of nodes whose collision shapes are solid, besides the bodies on the world mask. Default none |
| `--wall-layer` | Name of the `TileMapLayer` that holds walls. Every other layer is floor. Default `Walls` |
| `--world-mask` | Collision layer bits of the static bodies and tile polygons that block the player. Default `1` |
| `--player <res://…tscn>` | The player scene: the collision shapes directly under its root are the player's box |
| `--player-group` | Else the node of the level in this group. Default `player` |
| `--size WxH` | Else a box this big, centred on the feet |
| `--reach <px>`, `--step <px>` | How near a node the player must be able to stand to reach it (default 16), and the sampling step (default 2) |
| `--no-navigation` | Skip the navigation checks, for a game whose enemies do not use `NavigationRegion2D` |
| `--image <absolute.png>` | Writes a map of the level and of what the search found |

## What it reports

- `FAIL <node> at (x, y), cell (c, r) stands where the player cannot reach`: sealed room, passage too narrow for the player, or a prop on top of it. `stands in a wall, a prop or outside the level` is the same mistake on the spot.
- `FAIL <node> cannot be reached`: a required node with nowhere to stand within `--reach` of its collision shape or position.
- `FAIL reachable floor outside the camera limits`: the first `Camera2D` of the level, or of the `--player` scene, does not cover reachable floor. No camera: the limits are skipped and the summary says so.
- `FAIL … no navigation path to the spawn`, `no NavigationRegion2D with a baked polygon`: the bake is missing, or enemies stand outside it or on an island of it.
- `FAIL the navigation polygon is inset … but the enemies' collision shape reaches …`: the polygon's agent radius is smaller than how far the enemies' shapes reach from their feet, so the bake is stale. Rebake.
- The last line always starts with `level_check:`. Without it, nothing was checked. Exit 0 is a pass, 1 a failure, 2 bad arguments.

On failure, open the map: walls grey, props brown, reachable floor green, unreachable floor red, spawn blue, enemies white, required nodes yellow, the navigation outline magenta. Fix the level, never the check, and rerun.

## What the level has to follow

A level that breaks these gets a wrong answer, not an error.

- **Floor:** every `TileMapLayer` except the wall layer. A tile with a world-mask collision polygon is solid in the shape of the polygon. On the wall layer a tile without one is solid as a whole cell.
- **Props:** a static body on the world mask, or in a solid group, blocks by its collision shapes: rectangle, circle, capsule or polygon. Put those at the base of the prop, never over the whole sprite.
- **Player:** the shapes are read around the feet, so the player's origin is at the feet. The level is never run, so nothing a script adds at run time counts.
- **Spawn, enemies, required nodes:** `Node2D`s whose origin is at the feet; a required node with a shape is reached from any side of it.
- **Navigation:** a `NavigationRegion2D` with a baked `NavigationPolygon`, with an `agent_radius` at least the enemies' reach from their feet.

## What it does not check

Line of sight, enemy behaviour, one-way movement, doors or switches that change the level, and whether a fight is fair or fun. Check those by playing.

## Report

The `level_check:` line of every level, every `FAIL` line, what was fixed, and which levels were not checked and why, in under 150 words.
