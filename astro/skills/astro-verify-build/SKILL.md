---
name: astro-verify-build
description: Pre-commit gate for Astro projects. Use before every commit touching an Astro site's source, or to verify, check or validate an Astro build. Runs astro check, lint and format check, the production build, and, for visible changes, the served pages. Reports which gates ran and what they said.
---

# Verify an Astro build before committing

Four gates, in order. Gates 1-3 always run; Gate 4 runs when the commit touches anything under `src/` a visitor can see. Commit only when every gate that applies is green. Never report a gate as passing without running it and reading its output.

A commit touching only documentation or files the build never reads has nothing to verify: say so and skip.

Use the project's own scripts (`package.json` names them, the lockfile the package manager). Commands below are for npm.

## Gate 1 — Types

```bash
npm run typecheck    # astro check
```

`astro check` typechecks `.astro` templates; `tsc --noEmit` ignores them and exits clean on a template that does not compile. It needs `@astrojs/check`; if missing, say so and ask before adding it, rather than falling back to `tsc`. A clean check says nothing certain about content entries: a schema violation only fails in Gate 3.

## Gate 2 — Lint and format

```bash
npm run lint
npm run format:check
```

Run the project's linters (ESLint, Stylelint) and the formatter in check mode. None present means absent, never passing.

Check mode, never write mode. If the project's script writes, do not append `--check`: the write flag remains, the formatter fixes the files and exits 0. Call the check mode directly (`npx prettier --check .`). Fix lint failures at the cause, never with a disable comment.

## Gate 3 — The production build

```bash
npm run build    # astro build
```

This validates every content entry against its schema (a missing required field or a value outside an `enum` fails only here) and resolves the real import graph (missing stylesheet, bad asset path, wrong component name). Read the whole output: Astro prints warnings (route collision, empty collection) while exiting 0, and each is a failure until explained.

## Gate 4 — The site as served

Skip only when the commit changes nothing a visitor can see. Gates 1-3 do not prove a page renders: it can bundle and still produce empty markup or a collapsed grid.

```bash
npm run preview    # astro preview
```

Exercise what the commit changed against preview, never `astro dev`, which does not serve what ships.

If the project has a browser test suite, run it against the build. "No tests found" is a failure (the runner is looking elsewhere); read the count, not the exit code.

Beyond the suite, only for visual changes or when the caller asks, open and look at the page:
- at a narrow viewport (360 px) as well as wide;
- with `prefers-reduced-motion: reduce`: nothing the commit animates may move;
- with JavaScript disabled if a client script was added.

## Reporting

State which gates ran, which were skipped or absent and why, and what each said, in under 150 words. On failure, fix the cause and re-run from Gate 1. Never commit around a failure or call a skipped gate passing. Green gates do not mean the work is right; design consistency and usability still need review.
