---
name: python-verify-build
description: Pre-commit gate for Python projects. Use before every commit touching Python source, or to verify, check or validate a Python change. Runs the type checker, lint and format check, the test suite, the package build when distributed, and the changed code itself. Reports which gates ran and what they said.
---

# Verify a Python change before committing

Five gates, cheap to expensive. Gates 1-3 always run. Gate 4 runs when the project is built into a package and the commit touches what goes into it. Gate 5 runs when the commit changes something that runs. Commit only when every gate that applies is green. Never report a gate as passing without running it and reading its output.

A commit touching only documentation or files no check reads has nothing to verify: say so and skip.

## Use the project's environment

Find the commands in `pyproject.toml`, a `Makefile`/`justfile`, `tox.ini`/`noxfile.py` and the CI workflow (the best source: the list the project already agreed must pass). Commands below are for uv and common tools.

Run every tool through the project's environment (`uv run`, `poetry run`, the activated venv). A global install cannot see the project's packages, so it reports missing imports or treats them as untyped and passes unchecked code.

If the commit changes dependencies, first run `uv lock --check`: `uv run` re-locks and syncs, so a stale lockfile would be rewritten by the gate itself, changing the tree under the commit.

A gate the project lacks is reported absent, never replaced with your own tool, never passing.

## Gate 1 — Types

```bash
uv run mypy .    # or pyright: the project's checker, as it configures it
```

Use the project's configuration and add nothing. A flag that silences errors is not a fix; `--ignore-missing-imports` makes imported names untyped, so they pass. Confirm the checker reaches the paths the commit touched: a new package outside its configured paths is skipped silently.

## Gate 2 — Lint and format

```bash
uv run ruff check .
uv run ruff format --check .
```

Formatter in check mode, never write mode: `ruff check --fix` or a formatter without its check flag changes files and exits 0, a green light that altered the tree instead of inspecting it. Fix lint failures at the cause, never with `# noqa`.

## Gate 3 — Tests

```bash
uv run pytest
```

Run the whole suite: `-k` or a single path is for iterating and proves only what it selected. Read the summary:

- pytest exits 5 when it collects nothing. With tests present that is a failure: the runner looks where they are not.
- A test that ran before the commit and is skipped or xfail after is a finding, not a pass.
- A warning raised by the touched code is a failure.

## Gate 4 — The package build

Skip when the project is never built into a distribution or the commit leaves package contents and metadata untouched.

```bash
uv build    # or: python -m build
```

Tests run on the source tree; the wheel holds only what the build configuration includes, so a data file, template or `py.typed` can be missing while tests pass. If the commit adds a non-Python file, confirm it is in the wheel (`python -m zipfile -l dist/<name>.whl`). Then install the wheel in a clean environment outside the repository and import the package: an import that works only from the source tree is the failure this gate catches.

## Gate 5 — Run what changed

Skip only when nothing that runs changed. Earlier gates do not prove the program starts or the change works.

- Drive the changed path end to end through the entry point a user would use. A help message verifies nothing about a new command.
- Keep throwaway scripts in a scratch directory outside the repository, never committed.
- Never touch real data: ask the system for a free port, use an in-memory or temporary database.
- Shut down what you started. A hang is a failed gate.
- Read all output: a traceback, warning or unawaited-coroutine notice is a failure even on exit 0.

## Reporting

State which gates ran, which were skipped or absent and why, and what each said, in under 150 words. On failure, fix the cause and re-run from Gate 1. Never commit around a failure or call a skipped gate passing. Green gates do not mean the work is right.
