---
name: godot-verify-build
description: Pre-commit gate for Godot 4 projects. Use before every commit that touches scripts, scenes, resources, shaders or project settings in a Godot project, or when asked to verify, check, validate or smoke-test a Godot change. Imports the project headless, loads every script, scene, resource and shader with a bundled checker that fails on any engine error, runs the project's linter and tests, runs the scenes the change touched, and exports when the commit touches what ships. Reports which gates ran and what they said.
compatibility: Needs the Godot 4 editor binary. The bundled checker needs Godot 4.5 or later.
---

# Verify a Godot change before committing

Six gates, in order. Gates 1, 2 and 5 always run. Gates 3 and 4 run when the project has a linter or a test suite. Gate 6 runs when the project has an export preset and the commit touches what ships. A commit only happens when every gate that applies is green. Never report a gate as passing without having run it and read its output.

A commit that touches only documentation, or files the engine never reads, has nothing to verify. Say so plainly and skip, rather than inventing a green run.

## The exit code is not the result

Godot exits 0 from almost every failure. A script that does not parse, a scene that references a file that does not exist, an error thrown in `_ready`, a main scene that is missing altogether: each one prints an error and exits 0.

So for every command below, capture the output and read it. A line that starts with `ERROR:`, `SCRIPT ERROR:`, `SHADER ERROR:` or `WARNING:` is a finding, whatever the exit code says. Errors are written to standard error: capture both streams with `2>&1`, or they are lost.

## Use the project's engine

`godot` below stands for the editor binary: the one on the `PATH`, the one the project's CI or a `GODOT` or `GODOT_BIN` variable names, or on macOS `/Applications/Godot.app/Contents/MacOS/Godot`. An export template cannot run these commands.

Compare `godot --version` with `config/features` in `project.godot`. If the minor versions differ, stop and say so: an editor newer than the project may convert files as it opens them, and the gates would then be checking a project nobody committed.

Run from the project root with `--headless --path .`. Paths in the commands are for a project at the repository root; adjust `--path` when it is not.

## Gate 1 — Import

```bash
godot --headless --path . --import
```

This rebuilds `.godot/`: the imported form of every asset, and the list of classes that scripts declare with `class_name`. Every later gate depends on it. Without it a script that names one of those classes fails with `Could not find type`, and a texture has no imported data to load.

It checks nothing else. A script that does not parse goes through an import in silence.

Then read `git status --short`. Import writes a sidecar next to every new file: `<asset>.import` beside an asset, `<file>.uid` beside a script or a shader. Those sidecars hold the import settings and the identifier that scenes refer to, and they are part of the commit:

- An untracked sidecar means the commit is incomplete. Add it.
- A sidecar whose file is gone is an orphan. Delete it.
- A modified `.import` file the commit did not mean to touch needs an explanation: the asset was reimported with other settings, or by another engine version.
- Nothing under `.godot/` is ever committed.

## Gate 2 — Everything loads

```bash
godot --headless --path . --script /absolute/path/to/scripts/check_project.gd
```

`scripts/check_project.gd` is bundled with this skill. Give Godot its absolute path. It loads every script, scene, resource and shader in the project, and exits 1 when the engine reports an error for any of them:

```text
FAIL res://entities/slime.gd
  Parse Error: Could not find type "Stats" in the current scope. (res://entities/slime.gd:4)
FAIL res://levels/cave.tscn
  Resource file not found: res://tiles/cave.png (expected type: Texture2D)
check_project: 212 files checked, 2 failed, 0 with warnings
```

- **The last line has to be there.** A run that does not end with a `check_project:` line checked nothing. When Godot cannot load the script it was asked to run — a wrong path, an engine older than 4.5 — it prints an error and exits 0.
- `-- --skip res://addons` leaves a directory or a file out, and can be repeated. Use it for third-party code the project cannot fix, and name what you skipped in the report.
- A `WARN` entry is not a pass. It usually means a reference that no longer matches, such as a stale `uid` that fell back to the path. Explain each one or fix it.

What it catches: a script that does not parse or compile, including a warning the project has promoted to an error; a scene or resource that points at a file that is not there; a shader that does not compile.

What it cannot catch: it loads, it does not run. A node path that does not exist, a call on `null`, a missing input action or a signal connected to a method that was renamed only fail when the code executes, which is Gate 5. Shaders are checked against the shading language with no real renderer behind it, so a failure specific to one rendering backend only shows when the scene is drawn.

Do not use `--check-only` in its place. It exits 0 on a parse error, it reports any script that uses an autoload as broken because autoloads are not registered in that mode, and it starts the engine once per script.

In a C# project, `dotnet build` is the compile gate for the scripts. The checker still covers scenes and resources.

## Gate 3 — Lint and format

The engine has no linter or formatter for GDScript. Projects that have one use a third-party tool, so find which in the CI workflow, the `Makefile` or the pre-commit configuration, and run it as configured:

```bash
gdlint .                          # gdtoolkit
gdformat --check .                # gdtoolkit
gdscript-formatter --check <path> # GDQuest's formatter
```

A project with neither has no Gate 3: report it as absent, never as passing, and do not install one to fill the gap.

Check mode, never write mode. Both formatters rewrite files when run without `--check` and exit 0: a green light that changed the working tree instead of inspecting it.

A finding is fixed at its cause. An `@warning_ignore` added to get past a warning, or a warning level lowered under `debug/gdscript/warnings/` in `project.godot`, is a failure of this gate.

## Gate 4 — Tests

Godot has no test runner for game code. Projects use an addon, most often GUT or gdUnit4. Run the suite with the command the project's CI uses. The usual forms are:

```bash
godot -d -s --path "$PWD" addons/gut/gut_cmdln.gd -gexit    # GUT
./addons/gdUnit4/runtest.sh -a res://test                   # gdUnit4, needs GODOT_BIN set
```

- GUT exits 1 when a test fails. Without `-gexit` it never exits at all. Pending tests do not change the exit code.
- gdUnit4 exits 100 on failures and 101 on warnings. It stops at the first failure unless `-c` is given.

Run the whole suite, and read the summary rather than the exit code. A run that reports no tests in a project that has them is a failure: the runner is looking somewhere the tests are not, and every assertion is silently absent. Read the counts of skipped and pending tests too. A test that ran before the commit and is pending after it is a finding.

## Gate 5 — Run what changed

```bash
godot --headless --path . --fixed-fps 60 --quit-after 600                         # the main scene
godot --headless --path . res://levels/cave.tscn --fixed-fps 60 --quit-after 600  # one scene
```

`--quit-after` counts frames, and without it the game never exits. `--fixed-fps 60` makes each of those frames advance a sixtieth of a second of game time however fast the machine runs them. Six hundred frames are then ten seconds of game, in which timers fire and animations finish, and they take a fraction of a second.

Run the main scene, and every scene the commit touched.

In a 2D platformer, a commit that changes a level, the player's movement or its tuning also runs the `godot-2d-platformer-level-check` skill on every level it can affect: running a level proves it loads, not that it can be finished.

- A script error does not stop the game. The function that hit it is abandoned and everything else carries on, so one error can leave the scene in a state that no later line explains. Fix the first error first.
- A scene that sits idle proves that it loads, not that the change works. Drive the path the commit touched: with the project's tests, or with a throwaway script run with `--script` that `extends SceneTree`, instances the scene in `_initialize()`, calls into it, lets frames pass with `await process_frame`, prints what it observes and ends with `quit(code)`.
- Feed input with `Input.parse_input_event()` and an `InputEventAction`. `Input.action_press()` only changes what polling sees, and never reaches `_input` or `_unhandled_input`.
- Throwaway scripts live in a scratch directory outside the repository, and are never committed. Pass their absolute path to `--script`.
- The run writes to the real `user://` directory, the same one a play session on this machine uses. Do not exercise saving or deleting against it unless the project can point its save path somewhere else for the run.
- A run that does not end is a failed gate: something is keeping the game from quitting.

A change to what the player sees is not verified until a frame has been looked at. Capture frames with a real renderer and open them:

```bash
mkdir -p /tmp/shots
godot --path . res://levels/cave.tscn --write-movie /tmp/shots/frame.png --fixed-fps 60 --quit-after 120
```

This opens a window, so it needs a display. With `--headless` it crashes instead of recording. It writes one numbered PNG per frame, and a WAV next to them. With the `viewport` stretch mode the frames come out at the project's base size.

## Gate 6 — The export

Skip when the project has no `export_presets.cfg`, or when the commit changes nothing that ships.

```bash
godot --headless --path . --export-pack "<preset>" /absolute/path/outside/the/repo/game.pck
godot --headless --main-pack /absolute/path/outside/the/repo/game.pck --fixed-fps 60 --quit-after 600
```

The first command builds the game's data pack for a preset named in `export_presets.cfg`. An unknown preset name is one of the few failures that exits 1. A relative output path resolves against the project directory, not the current one, and the target directory has to exist: use an absolute path outside the repository. `--export-pack` builds only the pack, which is enough to check what is in it. `--export-release` builds the whole game, and needs the export templates for that engine version installed.

The second command runs the game from that pack rather than from the project folder. Read its output as in Gate 5.

An export validates nothing. A script that does not parse is packed without a word, which is why this gate comes after Gate 2. What the packed game changes is where files are and how they are named:

- Files that are not Godot resources — `.json`, `.txt`, `.csv` — are left out of the pack unless the preset's include filter names them. Reading one with `FileAccess` works in the editor and fails in the exported game. When the commit adds such a file, check `include_filter` in `export_presets.cfg`.
- Text scenes and resources are converted to binary on export by default. Code that opens a `.tres` or `.tscn` as a file, instead of calling `load()`, finds nothing there.
- Paths in a pack are case-sensitive. `res://Sprites/hero.png` for a file in `sprites/` loads on macOS and Windows and fails once exported.
- `res://` is read-only in an exported game. Anything the game writes goes to `user://`.

## Reporting

State plainly which gates ran, which were skipped or absent and why, and what each said. Quote the engine's own error lines. If a gate fails, fix the cause and re-run from Gate 1. Never commit around a failure, and never describe a skipped gate as passing.

Passing the gates is not the same as the work being right. The gates catch what a machine can catch; whether the game plays well still needs someone to play it.
