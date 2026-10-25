# Core

Stack-agnostic agents and skills that apply to any project.

## Agents

| Agent | What it does |
| :- | :- |
| [commit-writer](agents/commit-writer.md) | Checks that nothing private or local-only is staged, writes a single-line Conventional Commit header from the staged diff and creates the commit |
| [pr-develop-writer](agents/pr-develop-writer.md) | Writes the title and the What / Why / Testing description of a pull request into `develop` |
| [pr-release-writer](agents/pr-release-writer.md) | Writes the changelog-style pull request that releases `develop` into `main` |

The three git agents are designed to be used together: commits stay header-only and the pull request description carries the context.

## Skills

| Skill | What it does |
| :- | :- |
| [git-commit-hook](skills/git-commit-hook/SKILL.md) | Installs the `commit-msg` hook that enforces the header-only commit convention `commit-writer` follows |
| [verify-build](skills/verify-build/SKILL.md) | Pre-commit gate: runs the project's own type check, lint, tests and build in order, then exercises what changed |
