# Git hooks

Two hooks that need only POSIX `sh` and git.

| Hook | What it refuses |
| :- | :- |
| [commit-msg](commit-msg) | A commit whose message is not one line of the form `<type>: <description>` |
| [pre-push](pre-push) | A push that carries a commit with no signature |

## Add them to a repository

Run this from the root of the repository that should get the hooks:

```bash
curl -fsSL https://codeload.github.com/egobiian/dev-agents/tar.gz/refs/heads/main \
  | tar -xz --strip-components=1 dev-agents-main/.githooks
```

It creates `.githooks/` with both hooks, already executable, and this README. Files of the same name are overwritten, so run it again to update them. Delete the hook you don't want, then commit the directory so every clone gets it.

If the repository already manages hooks, with `.husky/`, `lefthook.yml`, `.pre-commit-config.yaml` or a `core.hooksPath` of its own, move the two files into that system instead. Two hook directories means one of them silently never runs.

## Turn them on

Git runs nothing from this directory until it is told to look here. Run this once in every clone:

```bash
git config core.hooksPath .githooks
```

`core.hooksPath` is local configuration and is never committed, so a fresh clone starts with the hooks off. Add the command to the setup steps of the project. In a Node project, the `prepare` script in `package.json` runs it whenever dependencies are installed:

```json
"prepare": "git rev-parse --git-dir >/dev/null 2>&1 && git config core.hooksPath .githooks || true"
```

## What they expect

**commit-msg** accepts exactly `<type>: <description>`. The type is one of `build` `chore` `ci` `docs` `feat` `fix` `perf` `refactor` `revert` `style` `test`, with no scope and no `!` marker. The description starts lowercase and has no trailing period. The header is 72 characters at most and the message is a single line, so there is no body, footer or trailer. Merge commits and the `fixup!`, `squash!` and `amend!` markers pass untouched.

Claude Code appends a `Co-Authored-By:` trailer to the commits it makes, which this hook rejects as a second line. Turn the trailer off in `.claude/settings.json`:

```json
{
  "attribution": {
    "commit": ""
  }
}
```

**pre-push** needs commit signing to be set up, or it blocks every push. It checks that each outgoing commit carries a signature, SSH or PGP, not that the signature verifies. GitHub documents the setup in [Signing commits](https://docs.github.com/en/authentication/managing-commit-signature-verification/signing-commits). To sign every commit without passing `-S`:

```bash
git config commit.gpgsign true
```

## Check that they run

```bash
git config --get core.hooksPath                  # .githooks

f=$(mktemp)
printf 'feat: add email validation\n' > "$f"
.githooks/commit-msg "$f"; echo "exit $?"        # exit 0
printf 'feat(auth): add email validation\n' > "$f"
.githooks/commit-msg "$f"; echo "exit $?"        # exit 1, "no scope"
rm "$f"
```

Don't bypass a hook with `--no-verify`. Fix the message, or sign the commit.
