---
name: audio-run-batches
description: Runs AI audio generation batches (effects, music) one after another without overheating the machine, from git-ignored local notes on where models run and how a batch starts; asks the owner to set them up first. Use when generating audio with a local model, setting up audio generation, or needing rests, a throttling wait and a log.
compatibility: The runner needs a POSIX shell. Its throttling wait uses macOS's pmset and is skipped where pmset does not exist.
---

# Run audio generation batches

Each machine runs its audio models its own way (a folder, a command, a batch format). None of it belongs in the repository: paths name the owner's machine and the command may name private tools. It lives in git-ignored local notes that the runner reads. Generation holds the machine at full load for minutes; the runner rests between batches and waits while the machine reports throttling. Paths to `scripts/` and `assets/` are relative to this skill's directory.

## The local notes

`audio/tool.local.md`, from [assets/tool-local-template.md](assets/tool-local-template.md):

- `TOOL_DIR`, the folder the command runs in, and `GENERATE`, the command for one batch (the runner appends the batch file's absolute path);
- `PYTHON`, a Python with numpy and soundfile, for the processing scripts;
- `REST_BETWEEN_BATCHES` in seconds (300 if omitted);
- the models and settings, the batch format with an example, and what the tool writes.

**The first time**, when the file does not exist:

1. Stop and ask the owner for the models, where they run, the command for one batch and its format. Never install a model, guess a path or search the disk. If none is installed, [references/local-models.md](references/local-models.md) describes one offline setup for a Mac with Apple Silicon: give it to them and leave installing to them.
2. Write the file from the template with their answers.
3. Make git ignore it: `git check-ignore -v audio/tool.local.md` must print a rule; otherwise add `*.local.md` to `.gitignore` in the same change.

Nothing in the notes (folder, command, tool name) is copied into a committed file: style guide, record of sources or commit message.

## Paid and metered generation

If the models are a paid service, this applies before any run; for local models, time and heat are the cost. Self-contained.

1. **Estimate** cost per sound and total, and check the balance or quota.
2. **Mock-up** for a new sound direction: one short clip in context, a few generations; the owner approves.
3. **Pilot**: one sound through the real pipeline; the owner approves.
4. **Production** only after approval, within the approved total.

Throughout:

- Ask before any batch over the limit agreed with the owner, even after "do it all".
- Write the failure criterion before an experiment; stop when you see it.
- Settle the whole system (tracks, lengths, loops, names) before producing; a late split can discard paid takes.
- Prefer reuse, re-trim or level changes to new generations. Two retries at most per sound.
- Stopping an agent does not stop jobs sent: check the provider's job list.
- Account and job ids stay out of version control, scratch and working files included: keep them in a folder git ignores.

## Write a batch

One folder per batch under a git-ignored scratch directory (`build/audio/<batch>/`), in the notes' format, outputs beside it. Name takes after what they are (`door_knock`, `level_one_theme`), never the game file they may replace. Keep batches as small as the style guide's limits say, with rests between sounds.

## Run it

```bash
sh /abs/path/to/scripts/run_batches.sh build/audio/<batch>/batch.toml > build/audio/<batch>/batch.log 2>&1
```

Run in the background and wait; do not poll in a loop. Several batch files in one call run in sequence with a rest between. `--notes <file>` reads other notes than `audio/tool.local.md`.

The log has `start`, `done` or `failed (exit n)` per batch, `resting`, `CPU limited to n%, waiting` while macOS reports throttling, and `all done`. Tools often buffer output, so lines may arrive in blocks. Exit 0: all batches ended well; 1: one failed; 2: bad arguments or missing notes.

While it runs: update the owner now and then, start nothing heavy (build, import, export, second batch), and never start a batch as a side effect of another task.

## Then

Read the log, list the takes each batch wrote, and continue with `audio-process-takes`: measure, rule out failures, let the owner listen.

## Report

Batches run and their duration, throttling or rests seen, takes written, generations spent against the estimate, and any failure with its error, in under 150 words.
