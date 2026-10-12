# Godot

Agents and skills for [Godot 4](https://godotengine.org) projects. Names in this section start with `godot-`.

They expect the Godot editor binary to be installed: the agents verify their work by running the engine, not by reading their own code. Everything here was written and tested against Godot 4.7.

For the art itself — style guide, palette, drawing and checking sprites — see the [pixel-art](../pixel-art/README.md) section.

## Agents

| Agent | What it does |
| :- | :- |
| [godot-developer](agents/godot-developer.md) | Builds gameplay — scenes, nodes, GDScript, signals, resources, input and physics — editing scene files as text and verifying by running the engine |
| [godot-ui-developer](agents/godot-ui-developer.md) | Builds menus and HUDs with containers and the project theme, with keyboard and controller navigation, and checks them at several window sizes |
| [godot-shader-developer](agents/godot-shader-developer.md) | Writes shaders and visual effects in the Godot shading language for the renderer the project targets |
| [godot-reviewer](agents/godot-reviewer.md) | Read-only review of scripts, scenes and resources for what only fails at run time in Godot |

The three builders split the work by the kind of file: gameplay scenes and scripts, Control scenes and themes, and shaders. The reviewer reads what they produce and changes nothing.

## Skills

| Skill | What it does |
| :- | :- |
| [godot-verify-build](skills/godot-verify-build/SKILL.md) | Pre-commit gate for Godot: headless import, a bundled checker that loads every script, scene, resource and shader, lint, tests, running what changed, and the export |
| [godot-pixel-art-setup](skills/godot-pixel-art-setup/SKILL.md) | Configures a project to render pixel art crisply — base resolution, stretch mode, integer scaling, filtering, snapping — and diagnoses one that does not |

`godot-verify-build` bundles `scripts/check_project.gd`, which needs Godot 4.5 or later. Godot exits 0 from almost every failure, so the checker is what gives the gate a real exit code.
