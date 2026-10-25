---
name: audio-run-batches
description: Runs batches of AI audio generation — sound effects and music from models running on the machine or behind a command — one after another without overheating it, from local notes that say where the models run and how a batch is started and that never reach git. Sets those notes up the first time from a template, by asking the owner rather than searching the disk. Use when generating sound effects or music with a local model, when setting up a project to generate audio for the first time, or when a generation run needs rests, a throttling wait and a log.
compatibility: The runner needs a POSIX shell. Its throttling wait uses macOS's pmset and is skipped where pmset does not exist.
---

# Run audio generation batches

Each project and each machine runs its audio models in its own way: a folder of its own, a command, a batch format. None of that belongs in the repository. Paths name the owner's machine, and the command often names private tools. It lives in local notes that git ignores, and the runner reads it from there.

Generation keeps the machine at full load for minutes. A laptop heats, throttles and slows down, and a batch started on a hot machine takes longer and heats it more. The runner rests between batches and waits while the machine reports that it is throttled.

Paths to `scripts/` and `assets/` are relative to this skill's directory.

## The local notes

`audio/tool.local.md`, from the template in [assets/tool-local-template.md](assets/tool-local-template.md). It holds:

- `TOOL_DIR`, the folder the generation command runs in, and `GENERATE`, the command that generates one batch: the runner appends the batch file's absolute path to it;
- `PYTHON`, a Python with numpy and soundfile, for the processing scripts;
- `REST_BETWEEN_BATCHES` in seconds, 300 if left out;
- the models and their settings, the batch file format with an example, and what the tool writes.

**The first time**, when the file does not exist:

1. Stop and ask the owner: which models, where they run, the command that generates one batch, and the format it reads. Never install a model, never guess a path, never search the disk for one. If the owner has no models installed yet, [references/local-models.md](references/local-models.md) describes one setup that works offline on a Mac with Apple Silicon: give it to them, and leave the installing to them.
2. Write the file from the template with their answers.
3. Make sure git ignores it: `git check-ignore -v audio/tool.local.md` prints the rule that covers it. If it prints nothing, add `*.local.md` to `.gitignore` in the same change.

Nothing in the notes — the folder, the command, the tool's name — is ever copied into a committed file: not into the style guide, not into the record of sources, not into a commit message.

## Write a batch

Each batch in its own folder under a scratch directory git ignores, such as `build/audio/<batch>/`, in the format the notes give, with its outputs beside it. Name each take after what it is (`door_knock`, `level_one_theme`), never after the game file it may replace. Keep a batch as small as the style guide's limits say, with its rests between sounds.

## Run it

```bash
sh /abs/path/to/scripts/run_batches.sh build/audio/<batch>/batch.toml > build/audio/<batch>/batch.log 2>&1
```

Run it in the background and wait for it to end; do not poll it in a loop. Several batch files in one call run one after another with a rest between them. `--notes <file>` reads other notes than `audio/tool.local.md`.

The log has a line for each step: `start`, `done` or `failed (exit n)` for each batch, `resting`, `CPU limited to n%, waiting` while macOS reports the CPU throttled, and `all done` at the end. Many tools buffer their output, so lines may arrive in blocks. The runner exits 0 when every batch ended well, 1 when one failed, and 2 on bad arguments or missing notes.

While it runs:

- give the owner a line on its progress now and then;
- start nothing heavy: no build, no import, no export, no second batch;
- never start a batch as a side effect of another task.

## Then

Read the log, list the takes each batch wrote, and continue with the `audio-process-takes` skill: measure them, rule out the failures, and let the owner listen.

## Report

The batches run, how long they took, any throttling or rest the log shows, the takes written, and any batch that failed with its error.
