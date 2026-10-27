---
name: delegate-work
description: How a main session plans, delegates to subagents and spends tokens and paid generations sparingly. Use when orchestrating subagents, writing a brief for one, batching fixes, choosing models, or before any paid generation batch (images, audio, video).
---

# Delegate work and spend little

The main session decides, plans and checks. Subagents build. Every token a subagent reads or writes is paid for, and every paid generation is spent for good, so both are budgeted like money.

## Decide before you delegate

- Make one-line fixes yourself. Handing them off costs more than doing them.
- Group related bugs and small changes into one agent run, not one run each.
- Delegate only work whose brief you can write in full. If you cannot say what done looks like, the task is not ready.
- Keep a short list of what is decided (style, scope, rules). Do not reopen an item unless the owner asks.

## Write the brief once

A subagent knows only its brief. Give it everything at once, using [assets/brief-template.md](assets/brief-template.md):

- the goal and what done looks like;
- the exact files or sections to read, and "read nothing else";
- what is already decided and must not change;
- the budget: tokens to stay lean, paid generations as a hard cap;
- whether it may commit (usually not);
- the report: format and a word limit.

## Read little

- Search first, then read line ranges. Never read whole folders.
- Look at an image only to judge something just made, and only once. An image costs far more than text.
- Never read a subagent's raw transcript. Wait for its report.

## Report short

Reports stay under the word limit in the brief, 150 words by default: what changed, what ran, what failed, what is open. No restating the brief, no file dumps.

## Choose the model

- The main session, on the strongest model, decides and reviews.
- Builders run on a mid-size model (for example `sonnet`).
- Mechanical work, such as commits, running checks or renaming, runs on the smallest model that is reliable (for example `haiku`).

## Run agents well

- Run agents in parallel only when they touch different files. Two writers on one file lose work.
- Resume an agent that already holds the context instead of starting a new one.
- Commit only after every agent writing files has finished, or a commit can pick up half-written files.
- Verify cheap to expensive: compile, run and read the output first. Screenshots, frame captures and browser runs come last, and only when the change is visual or the owner asks.

## Paid generation (images, audio, video, any metered API)

1. **Estimate.** Before a batch, give the cost per item and the total, and check the balance.
2. **Mock-up.** For any new look or system, make one still that shows the final result in context, at 5 to 10 generations. The owner says yes or no before anything is animated or produced in quantity.
3. **Pilot.** Make one item, or one direction and one animation, in the real pipeline, at about 50 generations at most. The owner judges it in place.
4. **Production.** Only after the pilot is approved, and only within the approved total.

Rules that hold throughout:

- Ask before any batch over the limit agreed with the owner, even after a broad "do it all". A test that becomes production is a new decision.
- Write down, before starting, what would make the experiment a failure, and stop when you see it.
- Settle the whole system before producing. A late change, such as splitting a part off, can throw away everything already generated.
- Prefer the cheapest method that is good enough: reuse, recolour, place or retexture existing output before generating new frames.
- Stopping an agent does not stop jobs it already sent. Check the provider's job list after stopping.
- Account and job ids stay out of version control. Keep working files that hold them in a folder git ignores.

## The project's standing rules

Paste [assets/claude-md-snippet.md](assets/claude-md-snippet.md) into the project's `CLAUDE.md` or `AGENTS.md`. It is short because it is loaded on every turn; this skill holds the detail.
