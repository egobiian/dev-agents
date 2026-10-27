---
name: godot-verify-build
description: Pre-commit gate for Godot 4 projects. Use before a commit that touches scripts, scenes, resources, shaders or project settings, or to verify, check, validate or smoke-test a Godot change. Imports headless, loads every script, scene, resource and shader with a bundled checker, runs lint, tests and changed scenes, and exports when what ships changed.
compatibility: Needs the Godot 4 editor binary. The bundled checker needs Godot 4.5 or later.
---

# Verify a Godot change before committing

Six gates, in order. Gates 1, 2 and 5 always run; 3 and 4 when the project has a linter or tests; 6 when it has an export preset and the commit touches what ships. Commit only when every applicable gate is green, and never report a gate as passing without running it and reading its output. A commit touching only documentation or files the engine never reads has nothing to verify: say so and skip.

## The exit code is not the result

Godot exits 0 from almost every failure: a script that does not parse, a scene pointing at a missing file, an error in `_ready`, a missing main scene. For every command below capture both streams (`2>&1`; errors go to stderr) and read the output. A line starting `ERROR:`, `SCRIPT ERROR:`, `SHADER ERROR:` or `WARNING:` is a finding.

## Use the project's engine

`godot` is the editor binary: on the `PATH`, named by the project's CI or a `GODOT`/`GODOT_BIN` variable, or on macOS `/Applications/Godot.app/Contents/MacOS/Godot`. An export template cannot run these commands.

Compare `godot --version` with `config/features` in `project.godot`. If the minor versions differ, stop and say so: a newer editor may convert files as it opens them, and the gates would check a project nobody committed.

Run from the project root with `--headless --path .`; adjust `--path` if the project is not at the repository root.

## Gate 1 - Import

```bash
godot --headless --path . --import
```

Rebuilds `.godot/`: imported assets and the list of `class_name` classes. Every later gate depends on it; without it a script naming such a class fails with `Could not find type`. It checks nothing else: a script that does not parse goes through silently. If it prints a file-open error while another agent is running the engine, rerun before treating it as real.

Then read `git status --short` and `git diff project.godot`:

- Import writes `<asset>.import` beside assets and `<file>.uid` beside scripts and shaders. An untracked sidecar means the commit is incomplete: add it. A sidecar whose file is gone is an orphan: delete it. A modified `.import` the commit did not mean to touch needs an explanation (other settings or engine version).
- The editor can reorder `project.godot` and drop settings it does not know for the running platform, such as `rendering_method.web`. Restore anything lost.
- Nothing under `.godot/` is ever committed.

## Gate 2 - Everything loads

```bash
godot --headless --path . --script /absolute/path/to/scripts/check_project.gd
```

`scripts/check_project.gd` is bundled with this skill; give Godot its absolute path. It loads every script, scene, resource and shader and exits 1 when the engine reports an error for any:

```text
FAIL res://entities/slime.gd
  Parse Error: Could not find type "Stats" in the current scope. (res://entities/slime.gd:4)
check_project: 212 files checked, 2 failed, 0 with warnings
```

- **The last `check_project:` line has to be there.** Without it nothing was checked: a wrong path or an engine older than 4.5 prints an error and exits 0.
- `-- --skip res://addons` leaves out a directory or file (repeatable). Use it for third-party code you cannot fix and name it in the report.
- A `WARN` is not a pass; usually a stale `uid` that fell back to the path. Explain or fix each.

It catches scripts that do not parse or compile (including warnings promoted to errors), scenes and resources pointing at missing files, and shaders that do not compile. It loads, it does not run: bad node paths, calls on `null`, missing input actions and signals connected to renamed methods only fail in Gate 5. Shaders are checked with no real renderer, so a backend-specific failure shows only when drawn.

Do not use `--check-only`: it exits 0 on a parse error, reports any script using an autoload as broken, and starts the engine per script. In C#, `dotnet build` is the compile gate for scripts; the checker still covers scenes and resources.

## Gate 3 - Lint and format

Godot has no GDScript linter or formatter. Find the project's in its CI workflow, `Makefile` or pre-commit configuration and run it as configured:

```bash
gdlint .                          # gdtoolkit
gdformat --check .                # gdtoolkit
gdscript-formatter --check <path> # GDQuest's formatter
```

None configured means Gate 3 is absent: report it so, and install nothing. Always check mode: formatters rewrite files without `--check` and exit 0. Fix a finding at its cause; an added `@warning_ignore` or a lowered level under `debug/gdscript/warnings/` fails this gate.

## Gate 4 - Tests

Godot has no built-in test runner; projects use an addon (GUT, gdUnit4). Run the whole suite with the command CI uses:

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gexit    # GUT
./addons/gdUnit4/runtest.sh -a res://test                   # gdUnit4, needs GODOT_BIN set
```

- GUT exits 1 on failure and never exits without `-gexit`; pending tests do not change the code.
- gdUnit4 exits 100 on failures, 101 on warnings, and stops at the first failure unless `-c` is given.

Read the summary, not the exit code. No tests run in a project that has them is a failure (the runner looks in the wrong place). A test that ran before and is pending or skipped now is a finding.

## Gate 5 - Run what changed

```bash
godot --headless --path . --fixed-fps 60 --quit-after 600                         # main scene
godot --headless --path . res://levels/cave.tscn --fixed-fps 60 --quit-after 600  # one scene
```

`--quit-after` counts frames (without it the game never exits); `--fixed-fps 60` makes each advance 1/60 s of game time, so 600 frames are ten game seconds, in which timers fire and animations finish, in a fraction of a second. Run the main scene and every scene the commit touched.

In a 2D platformer, a commit that changes a level or the player's movement or tuning also runs `godot-2d-platformer-level-check` on every level it can affect: running proves it loads, not that it can be finished.

- A script error does not stop the game: the function is abandoned and the rest carries on. Fix the first error first.
- An idle scene proves it loads, not that the change works. Drive the touched path with the project's tests or a throwaway script run with `--script` that `extends SceneTree`, instances the scene in `_initialize()`, calls into it, awaits `process_frame`, prints what it sees and ends with `quit(code)`. Keep such scripts outside the repo and uncommitted.
- Feed input with `Input.parse_input_event()` and an `InputEventAction`; `Input.action_press()` only changes polling and never reaches `_input` or `_unhandled_input`.
- The run writes to the real `user://` of this machine. Do not exercise saving or deleting against it unless the save path can be redirected.
- A run that does not end is a failed gate.

Only when the change is visual or the caller asks, capture frames with a real renderer and look (needs a display; `--headless` crashes): `godot --path . res://levels/cave.tscn --write-movie /tmp/shots/frame.png --fixed-fps 60 --quit-after 120`. It writes one numbered PNG per frame plus a WAV; with the `viewport` stretch mode frames are at the base size.

## Gate 6 - The export

Skip without `export_presets.cfg` or when nothing that ships changed.

```bash
godot --headless --path . --export-pack "<preset>" /absolute/path/outside/the/repo/game.pck
godot --headless --main-pack /absolute/path/outside/the/repo/game.pck --fixed-fps 60 --quit-after 600
```

`--export-pack` builds only the data pack for a preset in `export_presets.cfg` (an unknown preset exits 1). The output path must be absolute, outside the repo, in an existing directory: a relative one resolves against the project. `--export-release` builds the whole game and needs the matching export templates. The second command runs the pack; read it as in Gate 5.

An export validates nothing: a script that does not parse is packed silently, hence Gate 2 first. What the pack changes is files and names:

- Non-resource files (`.json`, `.txt`, `.csv`) are left out unless the preset's `include_filter` names them: `FileAccess` works in the editor and fails exported.
- Text scenes and resources become binary; code opening a `.tres`/`.tscn` as a file finds nothing. Use `load()`.
- Paths are case-sensitive: `res://Sprites/hero.png` for `sprites/` fails once exported.
- `res://` is read-only exported; writes go to `user://`.

## Reporting

State which gates ran, which were skipped or absent and why, and what each said, quoting the engine's error lines. On failure, fix the cause and rerun from Gate 1. Never commit around a failure or call a skipped gate passing. The gates catch what a machine can; whether it plays well needs a person. Keep the report under 150 words.
