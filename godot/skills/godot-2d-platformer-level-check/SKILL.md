---
name: godot-2d-platformer-level-check
description: Proves that a level of a side-view 2D platformer made in Godot 4 can be finished. A bundled script simulates the player's run, jump, fall and drop-through from the project's own movement values, from every place the player can stand, and fails on an impossible jump, a pit or a corner the player cannot get out of, and a checkpoint or collectible nobody can reach; it can draw a map of what it found. Use after building or changing a level, after changing the player's movement or its tuning, before committing either, or when asked whether a level is beatable, fair or has softlocks.
compatibility: Needs the Godot 4 editor binary. The bundled script needs Godot 4.4 or later.
---

# Check that a level can be finished

Playing a level proves that one route works for one player on one try. It does not prove that the jump at the end works with a little less speed, or that the player who falls into the side pit can climb out. The script in [scripts/level_check.gd](scripts/level_check.gd) proves both, in a second or two, by searching every place the player can reach.

Paths to `scripts/` are relative to this skill's directory. Give Godot the absolute path.

## Run it

```bash
mkdir -p /tmp/level-maps
godot --headless --path . --script /abs/path/to/scripts/level_check.gd -- \
  res://levels/cave.tscn \
  --physics res://data/player_movement.tres \
  --player res://player/player.tscn \
  --image /tmp/level-maps/cave.png 2>&1
```

Run it on every level the change can affect. A change to the player's movement or to its tuning affects all of them.

| Option | What it gives |
| :- | :- |
| `--physics <res://…tres>` | The resource that holds the player's movement: `run_speed`, `jump_velocity` and `gravity`, and optionally `fall_gravity` and `acceleration`, in pixels and seconds |
| `--player <res://…tscn>` | The player scene. The first rectangle or capsule `CollisionShape2D` directly under its root gives the player's size |
| `--size WxH` | The player's size, instead of `--player` |
| `--run-speed`, `--jump-velocity`, `--gravity`, `--fall-gravity`, `--acceleration` | Single values, instead of `--physics` or over it |
| `--tolerance 0.9` | The fraction of jump height and run speed the route has to work with. The default 0.9 means no jump on the route is pixel-perfect |
| `--drop-layer platforms` | The physics layer whose one-way platforms the player can drop through |
| `--image <absolute.png>` | Writes a map of the level and of what the search found |

When the project names its movement values differently, pass them as single values, or give the resource properties with these names. Read them from the code that moves the player, never from a comment.

## What it reports

The first line names the level and the physics it used. Read it: a jump height that is not the one the game has means the values came from the wrong place.

- `FAIL the goal cannot be reached from the spawn. The route ends at feet (x, y)`: the furthest point the player gets to. The impossible jump is just past it.
- `FAIL trap: the goal cannot be reached from feet x a..b, y c`: a place the player can get into and not out of. Usually a pit too deep to jump out of, or a ledge dropped onto from above that leads nowhere.
- `FAIL checkpoint <path> cannot be reached`, `FAIL must_reach <path> cannot be reached`: no reachable place to stand within 24 px of that node.
- The last line always starts with `level_check:`. Without it, nothing was checked. Exit 0 is a pass, 1 a failure, 2 bad arguments.

When it fails, open the map. Solids are grey, one-way platforms brown, crumbling platforms tan, the lines of moving platforms steel blue, hazards magenta, ground the player can reach and still finish from green, traps red, the spawn blue, the goal yellow, checkpoints orange and places that must be reached cyan. Fix the level, never the check, and run it again.

## What the level has to follow

The script reads the level the way the game builds it. It relies on these conventions; a level that breaks them gets a wrong answer, not an error.

- **Terrain:** `TileMapLayer` cells with a collision polygon count as the full cell. One-way polygons are platforms. `StaticBody2D` children with a `RectangleShape2D` count too. No slopes.
- **Spawn:** exactly one node in group `player_spawn`, at the player's feet.
- **Goal:** a node in group `level_goal`: an `Area2D` with a `RectangleShape2D`, or a point the player has to pass.
- **Checkpoints:** nodes in group `checkpoints`, at feet height. **Anything else the player has to be able to get to** — a key, a switch, a collectible the game counts: a node in group `must_reach`, at its feet on the ground.
- **Hazards:** nodes in group `hazards` with a `get_local_rect() -> Rect2` method giving the area they cover in their own coordinates. A walk, jump or fall that touches one goes nowhere.
- **Crumbling platforms:** nodes in group `crumbling_platforms` with `get_local_rect()`. Droppable one-way platforms that hold the player only long enough to jump again, so from one only jumps and drops are tried, never a walk.
- **Moving platforms:** nodes in group `moving_platforms` with `get_line_rects(spacing: float) -> Array[Rect2]`, the platform's rectangle at points along the line it travels, no more than `spacing` apart, in its own coordinates where it starts. Each point counts as a crumbling platform, so riding to it and jumping or dropping from there is a route.
- **Void:** falling below the lowest solid is not a route. A game that puts the player back on safe ground after a fall is still checked as if the fall were the end.

## What it does not simulate

It is a model of a plain platformer seen from the side: run with acceleration, one jump at full height from a standstill, gravity that may be stronger on the way down, walking off ledges, dropping through platforms. Top-down, isometric and 3D levels move by other rules: this check says nothing about them. It does not know:

- double jumps, wall jumps, dashes, coyote time or jump buffering. A route that needs one is reported impossible. The check is then conservative: design the main route without them, or extend the script with the move;
- enemies, other moving bodies, doors, switches that change the level, slopes;
- whether a route is fun, readable or fair to someone seeing it for the first time.

A route that depends on any of these is checked by playing it.

## Report

The `level_check:` line of every level checked, every `FAIL` line, and what was fixed. Say which levels were not checked and why.
