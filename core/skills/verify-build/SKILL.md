---
name: verify-build
description: Pre-commit gate for any project. Use before every commit touching source, or to verify, check or validate a change before committing or opening a pull request. Finds the project's own type check, lint, test and build commands, runs them in order, and exercises what changed. Reports which gates ran. Prefer a stack-specific verify skill if one exists.
---

# Verify the build before committing

Five gates, cheap to expensive. Commit only when every gate that applies is green. Never report a gate as passing without running it and reading its output.

A commit touching only documentation or files the build never reads has no source to verify: say so and skip.

## Find the gates first

The project defines its checks. Read where it declares them (`package.json` scripts, `Makefile`/`justfile`, `pyproject.toml`, the CI workflow, the best single source) and use the commands as written. A gate the project lacks is reported absent, never replaced with a command of your choosing, never passing.

## Gate 1 — Types

Run the project's type check (for a compiled language, the compilation). Use its script, not the compiler directly: a bare call pointed at a root config that only references sub-projects finds no inputs, and unknown template formats are skipped, exiting 0 having verified nothing. If the commit adds a package or project directory, confirm the check reaches it.

## Gate 2 — Lint and format

Run linters, and the formatter in **check** mode, never write mode, which hides what the commit contains. If the project's script writes, do not append a check flag: the write flag remains, the files are fixed and it exits 0. Call the formatter's check mode directly. Fix lint failures at the cause, never with a disable comment.

## Gate 3 — Tests

Run the suite and read the summary, not just the exit code. With tests present, "no tests found" is a failure: the runner looks elsewhere and every assertion is absent. Never skip it because the change seems untestable.

## Gate 4 — The production build

Run the build that ships. It resolves the real graph: a missing asset, bad import path or undeclared dependency passes earlier gates and fails here. Read the whole output; warnings (an unresolved import above all) with exit 0 are failures.

## Gate 5 — Run what changed

Skip only when nothing that runs changed. Earlier gates prove it compiles, not that it starts or works.

- Run the built result (not the dev server, which does not serve what ships) and drive the path the commit changed, end to end. A start-up banner verifies nothing about a new feature.
- Keep throwaway scripts in a scratch directory outside the repository, never committed.
- Never touch real data: ask the system for a free port, use an in-memory or temporary database.
- Shut down what you started; a hang is a failed gate.
- Read all output: warnings and unhandled errors are failures even on exit 0.
- Only for a change to what a user sees, or when the caller asks, open and look at the result; automated checks have no opinion on whether it reads well.

## Reporting

State which gates ran, which were skipped or absent and why, and what each said, in under 150 words. On failure, fix the cause and re-run from Gate 1. Never commit around a failure or call a skipped gate passing. Green gates do not mean the work is right.
