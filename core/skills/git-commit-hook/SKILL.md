---
name: git-commit-hook
description: Installs a commit-msg git hook enforcing single-line Conventional Commit headers: known type, no scope or "!" marker, lowercase description, no trailing period, 72 characters, no body, footers or trailers. Use when setting up a repository, adding a commit hook, enforcing the commit convention, or when bad commit messages get through.
---

# Install the commit message hook

The hook in [assets/commit-msg](assets/commit-msg) rejects any commit whose message is not exactly `<type>: <description>`. It checks the mechanical rules only: type in `build` `chore` `ci` `docs` `feat` `fix` `perf` `refactor` `revert` `style` `test`; no scope, no `!`; lowercase description without a trailing period; 72 characters at most; a single line, which keeps bodies, footers and `Co-Authored-By:` trailers out. Mood and quality are left to review. Merge commits and `fixup!`, `squash!`, `amend!` pass. It needs only POSIX `sh` and git.

## Before installing

1. Check whether hooks are already managed: `git config --get core.hooksPath`, and look for `.husky/`, `lefthook.yml`, `.pre-commit-config.yaml`. If so, install into that system; two hook directories means one silently never runs.
2. If a `commit-msg` hook exists, stop and show it to the user rather than overwriting it.

## Install

1. Copy and make executable:

   ```bash
   mkdir -p .githooks
   cp <this-skill>/assets/commit-msg .githooks/commit-msg
   chmod +x .githooks/commit-msg
   git config core.hooksPath .githooks
   ```

2. Make it hold for every clone: `core.hooksPath` is local, so a fresh clone runs no hooks until that command runs there. In a Node project, add it to `prepare` in `package.json` (chain onto an existing `prepare`, do not replace it):

   ```json
   "prepare": "git rev-parse --git-dir >/dev/null 2>&1 && git config core.hooksPath .githooks || true"
   ```

   The guard avoids failing where there is no git directory, such as a container build. In other projects, add the command to the README setup steps.

3. Stop Claude Code adding its `Co-Authored-By:` trailer, which the hook rejects as a second line. Merge into `.claude/settings.json`, keeping existing content:

   ```json
   { "attribution": { "commit": "" } }
   ```

## Verify

Run the hook on message files; nothing is committed.

```bash
f=$(mktemp)
printf 'feat: add email validation\n' > "$f"; .githooks/commit-msg "$f"; echo "exit $?"   # 0
printf 'feat(auth): add email validation\n' > "$f"; .githooks/commit-msg "$f"; echo "exit $?"   # 1, no scope
printf 'fix: handle empty input\n\nMore.\n' > "$f"; .githooks/commit-msg "$f"; echo "exit $?"   # 1, one line only
rm "$f"
```

Then confirm `git config --get core.hooksPath` prints `.githooks`.

## Rules

- Never weaken the hook or bypass it with `--no-verify`; fix the message.
- Changing what the convention allows (a scope, a body) is the user's decision; ask before editing the hook.
- Report what you installed, what you changed in `package.json` and `.claude/settings.json`, and what the verification printed, in under 150 words.
