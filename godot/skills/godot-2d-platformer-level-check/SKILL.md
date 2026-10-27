---
name: godot-2d-platformer-level-check
description: Proves a side-view 2D platformer level in Godot 4 can be finished. A bundled script simulates run, jump, fall and drop-through from the project's movement values and fails on impossible jumps, inescapable pits and unreachable checkpoints; it can draw a map. Use after changing a level or the player's movement, or to check a level is beatable, fair or free of softlocks.
compatibility: Needs the Godot 4 editor binary. The bundled script needs Godot 4.4 or later.
---

# Check that a level can be finished

Playing a level proves one route for one player on one try. [scripts/level_check.gd](scripts/level_check.gd) searches every place the player can reach and proves the last jump works with a little less speed and that a side pit can be climbed out of. `scripts/` is relative to this skill's directory; give Godot the absolute path.

## Run it

```bash
mkdir -p /tmp/level-maps
godot --headless --path . --script /abs/path/to/scripts/level_check.gd -- \
  res://levels/cave.tscn \
  --physics res://data/player_movement.tres \
  --player res://player/player.tscn \
  --image /tmp/level-maps/cave.png 2>&1
```

Run it on every level the change can affect; a change to movement or tuning affects all of them.

| Option | What it gives |
| :- | :- |
| `--physics <res://…tres>` | The resource that holds the player's movement: `run_speed`, `jump_velocity` and `gravity`, and optionally `fall_gravity` and `acceleration`, in pixels and seconds |
| `--player <res://…tscn>` | The player scene. The first rectangle or capsule `CollisionShape2D` directly under its root gives the player's size |
| `--size WxH` | The player's size, instead of `--player` |
| `--run-speed`, `--jump-velocity`, `--gravity`, `--fall-gravity`, `--acceleration` | Single values, instead of `--physics` or over it |
| `--tolerance 0.9` | The fraction of jump height and run speed the route has to work with. The default 0.9 means no jump on the route is pixel-perfect |
| `--drop-layer platforms` | The physics layer whose one-way platforms the player can drop through |
| `--image <absolute.png>` | Writes a map of the level and of what the search found |

If the project names its movement values differently, pass single values. Read them from the code that moves the player, never from a comment.

## What it reports

The first line names the level and the physics used; a jump height that is not the game's means the values came from the wrong place.

- `FAIL the goal cannot be reached from the spawn. The route ends at feet (x, y)`: the furthest point the player gets to. The impossible jump is just past it.
- `FAIL trap: the goal cannot be reached from feet x a..b, y c`: a place the player can get into and not out of. Usually a pit too deep to jump out of, or a ledge dropped onto from above that leads nowhere.
- `FAIL checkpoint <path> cannot be reached`, `FAIL must_reach <path> cannot be reached`: no reachable place to stand within 24 px of that node.
- The last line always starts with `level_check:`. Without it, nothing was checked. Exit 0 is a pass, 1 a failure, 2 bad arguments.

On failure, open the map: solids grey, one-way brown, crumbling tan, moving-platform lines steel blue, hazards magenta, reachable finishable ground green, traps red, spawn blue, goal yellow, checkpoints orange, must-reach places cyan. Fix the level, never the check, and rerun.

## What the level has to follow

A level that breaks these conventions gets a wrong answer, not an error.

- **Terrain:** `TileMapLayer` cells with a collision polygon count as the full cell. One-way polygons are platforms. `StaticBody2D` children with a `RectangleShape2D` count too. No slopes.
- **Spawn:** exactly one node in group `player_spawn`, at the player's feet.
- **Goal:** a node in group `level_goal`: an `Area2D` with a `RectangleShape2D`, or a point the player has to pass.
- **Checkpoints:** nodes in group `checkpoints`, at feet height. **Anything else the player has to be able to get to** — a key, a switch, a collectible the game counts: a node in group `must_reach`, at its feet on the ground.
- **Hazards:** nodes in group `hazards` with a `get_local_rect() -> Rect2` method giving the area they cover in their own coordinates. A walk, jump or fall that touches one goes nowhere.
- **Crumbling platforms:** nodes in group `crumbling_platforms` with `get_local_rect()`. Droppable one-way platforms that hold the player only long enough to jump again, so from one only jumps and drops are tried, never a walk.
- **Moving platforms:** nodes in group `moving_platforms` with `get_line_rects(spacing: float) -> Array[Rect2]`, the platform's rectangle at points along the line it travels, no more than `spacing` apart, in its own coordinates where it starts. Each point counts as a crumbling platform, so riding to it and jumping or dropping from there is a route.
- **Void:** falling below the lowest solid is not a route. A game that puts the player back on safe ground after a fall is still checked as if the fall were the end.

## What it does not simulate

It models a plain side-view platformer: accelerated run, one full-height jump from a standstill, stronger fall gravity, walking off ledges, dropping through platforms. It says nothing about top-down, isometric or 3D levels, and does not know:

- double jumps, wall jumps, dashes, coyote time or jump buffering. A route that needs one is reported impossible. The check is then conservative: design the main route without them, or extend the script with the move;
- enemies, other moving bodies, doors, switches that change the level, slopes;
- whether a route is fun, readable or fair to someone seeing it for the first time.

Check routes that depend on these by playing.

## Report

The `level_check:` line of every level, every `FAIL` line, what was fixed, and which levels were not checked and why, in under 150 words.
