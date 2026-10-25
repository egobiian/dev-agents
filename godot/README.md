# Godot

Agents and skills for [Godot 4](https://godotengine.org) projects. Names in this section start with `godot-`, and those for one kind of game add it next: `godot-2d-platformer-` for side-view 2D platformers. Another kind, such as top-down games, gets a prefix and a heading of its own.

They expect the Godot editor binary to be installed: the agents verify their work by running the engine, not by reading their own code. Everything here was written and tested against Godot 4.7.

For the art itself — style guide, palette, drawing and checking sprites — see the [pixel-art](../pixel-art/README.md) section, and for sound the [audio](../audio/README.md) section.

## Any game

| Agent | What it does |
| :- | :- |
| [godot-developer](agents/godot-developer.md) | Builds gameplay — scenes, nodes, GDScript, signals, resources, input and physics — editing scene files as text and verifying by running the engine |
| [godot-ui-developer](agents/godot-ui-developer.md) | Builds menus, HUDs and touch controls with containers and the project theme, with keyboard, controller and touch input, and checks them at several window sizes |
| [godot-shader-developer](agents/godot-shader-developer.md) | Writes shaders and visual effects in the Godot shading language for the renderer the project targets |
| [godot-reviewer](agents/godot-reviewer.md) | Read-only review of scripts, scenes and resources for what only fails at run time in Godot |

The three builders split the work by the kind of file: gameplay scenes and scripts, Control scenes and themes, and shaders. The reviewer reads what they produce and changes nothing.

| Skill | What it does |
| :- | :- |
| [godot-verify-build](skills/godot-verify-build/SKILL.md) | Pre-commit gate for Godot: headless import, a bundled checker that loads every script, scene, resource and shader, lint, tests, running what changed, and the export |
| [godot-pixel-art-setup](skills/godot-pixel-art-setup/SKILL.md) | Configures a project to render pixel art crisply — base resolution, stretch mode, integer scaling, filtering, snapping — and diagnoses one that does not |

`godot-verify-build` bundles `scripts/check_project.gd`, which needs Godot 4.5 or later. Godot exits 0 from almost every failure, so the checker is what gives the gate a real exit code.

## 2D platformers

Side-view levels where the player runs and jumps against gravity.

| Agent | What it does |
| :- | :- |
| [godot-2d-platformer-level-designer](agents/godot-2d-platformer-level-designer.md) | Lays out levels from a readable map baked by a builder, keeps every jump in reach and every pit escapable, and proves it with `godot-2d-platformer-level-check` |

| Skill | What it does |
| :- | :- |
| [godot-2d-platformer-level-check](skills/godot-2d-platformer-level-check/SKILL.md) | Proves a level can be finished: a bundled script simulates run, jump, fall and drop-through from the project's movement values and fails on impossible jumps, traps and unreachable checkpoints |

`godot-2d-platformer-level-designer` preloads `godot-2d-platformer-level-check` through the `skills` field of its frontmatter, so copy the whole section rather than single files. The skill bundles `scripts/level_check.gd`, which needs Godot 4.4 or later, and relies on a few conventions in the level — groups for the spawn, the goal, checkpoints and hazards — listed in its page.
