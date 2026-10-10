---
name: astro-verify-build
description: Pre-commit gate for Astro projects. Use before every commit that touches source in an Astro site, or when asked to verify, check or validate an Astro build. Verifies types with astro check, lint and formatting, the production build, and — when the commit touches a page — that the built pages actually render and behave. Reports which gates ran and what they said.
---

# Verify an Astro build before committing

Four gates, in order. Gates 1–3 always run. Gate 4 runs when the commit touches anything under `src/` that a visitor can see. A commit only happens when every gate that applies is green. Never report a gate as passing without having run it and read its output.

A commit that touches only documentation, or files the build never reads, has no source to verify. Say so plainly and skip, rather than inventing a green run.

Use the project's own scripts: `package.json` names them, and the lockfile tells you the package manager. The commands below show what each gate has to run, written for npm.

## Gate 1 — Types

```bash
npm run typecheck    # the script that runs: astro check
```

`astro check` typechecks the `.astro` templates as well as the TypeScript. `tsc --noEmit` is not a substitute: it ignores `.astro` files entirely, so it exits clean on a template that does not compile.

It needs the `@astrojs/check` package. If the project does not have it, say so and ask before adding it, rather than falling back to `tsc`.

A clean type check says nothing certain about the content entries themselves. An entry that violates its collection schema is only certain to fail in Gate 3.

## Gate 2 — Lint and format

```bash
npm run lint
npm run format:check    # the formatter in check mode
```

Run whatever linters the project has — ESLint, Stylelint — and the formatter in check mode. A project with none of them has no Gate 2: report it as absent, never as passing.

Check mode, never write mode: a gate that silently reformats hides what the commit actually contains. If the project only has a script that writes, do not append `--check` to it. The write flag is still in the script, so the formatter fixes the files and exits 0 — a green light that changed the working tree instead of inspecting it. Call the check mode directly, for example `npx prettier --check .`.

A lint failure is fixed at its cause, never with a disable comment.

## Gate 3 — The production build

```bash
npm run build    # astro build
```

This is where content collections are actually validated. Astro reads every entry against its schema at build time, so an entry missing a required field, or carrying a value outside an `enum`, fails here and nowhere earlier.

It is also where the runtime import graph is resolved. A missing stylesheet, an asset path that does not exist, or a component imported under the wrong name can all typecheck cleanly and only fail at this gate.

Read the whole output, not just the exit code. Astro reports warnings — a route collision, a collection with no entries — while still exiting 0, and each of those is a failure here until it is explained.

## Gate 4 — The site as served

Skip only when the commit changes nothing a visitor can see.

The first three gates prove the site compiles. None of them proves a page renders: a component can bundle cleanly and then produce empty markup, a grid can collapse, a colour can end up unreadable.

```bash
npm run preview    # astro preview
```

Then exercise what the commit changed. Preview serves the real build; the dev server does not, and a check against `astro dev` verifies bytes that never ship.

When the project has a browser test suite, running it is the mechanical half of this gate. Confirm that it runs against the build rather than the dev server. A run reporting no tests found is a failure: it means the runner is looking somewhere the specs are not, and every assertion is silently absent. Read the count, not just the exit code.

What a suite does not cover, someone has to look at:

- A commit that changes what a page looks like is not verified until the page has been opened and looked at. A test asserts on structure and computed styles; it has no opinion about whether the result reads well.
- Check the change at a narrow viewport too. A layout that is fine at 1440 pixels can be unreadable at 360.
- Check it with `prefers-reduced-motion: reduce`. Nothing the commit animates may still move.
- Check the page with JavaScript disabled when the commit adds a client script. The content has to be readable without it.

## Reporting

State plainly which gates ran, which were skipped or absent and why, and what each said. If a gate fails, fix the cause and re-run from Gate 1. Never commit around a failure, and never describe a skipped gate as passing.

Passing the gates is not the same as the work being right. The gates catch what a machine can catch; whether the change is consistent with the design and usable still needs a review.
