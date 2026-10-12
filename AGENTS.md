# dev-agents

A collection of Claude Code subagents and Agent Skills, grouped into sections by stack. It is a library to browse and copy from. There is no build step, no plugin manifest and no marketplace: don't add `.claude-plugin/`, `plugin.json` or install tooling unless asked.

## Layout

```text
<section>/              one directory per stack: core (stack-agnostic), astro, ...
  README.md             index of every agent and skill in the section
  agents/<name>.md      subagents
  skills/<name>/        skills, each with a SKILL.md
templates/              starting points for new agents and skills
.githooks/              git hooks for this repo, which consumers can copy too
```

No agent or skill lives under `.claude/`, so none of them is active while you work on this repo; `.claude/` holds only the settings for working here. Consumers copy files into the `.claude/agents/` and `.claude/skills/` (or `.agents/skills/`) directories of their own projects.

Keep `agents/` and `skills/` flat. An installed skill has to sit directly under `.claude/skills/`, so a subfolder inside `skills/` would install where it is never found. Group related items with a shared name prefix such as `git-` or `pr-`. When a topic outgrows its section, give it a section of its own rather than a subfolder.

## Naming

- Lowercase letters, digits and single hyphens. 1 to 64 characters, no leading or trailing hyphen.
- Agent: the filename matches `name`. Skill: the directory name matches `name`, which the Agent Skills spec requires.
- Names are unique across the whole repo, because every section installs into the same flat `.claude/agents/` and `.claude/skills/` directories.
- Items in a stack section start with the section name, such as `astro-content-collections`. Items in `core` carry no section prefix.
- Don't reuse the name of a Claude Code built-in such as `code-review`, `init`, `Explore` or `Plan`. A project skill or agent with the same name replaces the built-in.

## Adding a skill

Skills follow the [Agent Skills specification](https://agentskills.io/specification).

1. Copy `templates/skill-template/` to `<section>/skills/<name>/` and set `name` to the directory name.
2. Write `description` in the third person: what the skill does, then when to use it, with the keywords a user would type. Maximum 1024 characters.
3. Keep the frontmatter to the portable fields: `name`, `description`, `license`, `compatibility`, `metadata`, `allowed-tools`. Tools other than Claude Code reject or ignore anything else.
4. Use a Claude Code-only field (`paths`, `disable-model-invocation`, `context`, `argument-hint`, `when_to_use`) only when the skill needs it, and then add `compatibility: Designed for Claude Code`.
5. Keep `SKILL.md` under 500 lines. Put detailed docs in `references/`, executable code in `scripts/` and templates or data in `assets/`. Link them from `SKILL.md` with relative paths, one level deep.
6. Add a row to the section `README.md`.

A script that several skills need is copied into each of them, so that every skill still works when it is copied on its own. `pixelkit.py` is the same file in the `scripts/` folder of `pixel-art-palette`, `pixel-art-draw` and `pixel-art-verify-assets`. Change the copies together.

## Adding a subagent

Subagents follow the [Claude Code subagent format](https://code.claude.com/docs/en/sub-agents).

1. Copy `templates/agent-template.md` to `<section>/agents/<name>.md` and set `name` to the filename without `.md`.
2. Write `description` as the delegation trigger: what the agent does and when Claude should hand work to it. Add "Use proactively" when it should run without being asked.
3. List only the tools the agent needs in `tools`. A read-only reviewer gets `Read, Grep, Glob`, not the full set.
4. Leave `model` out unless the agent needs a specific one. Frontmatter fields are camelCase and case-sensitive.
5. Write the body as a self-contained system prompt. A subagent receives only that body plus basic environment details, so it knows nothing about this repo or the conversation that invoked it.
6. When the agent works with a skill of its own section, list that skill in `skills` so that it is preloaded, and say in the body where to find it when it is not. The section `README.md` then says that the section is to be copied whole.
7. Add a row to the section `README.md`.

## Adding a section

1. Create `<section>/` with a lowercase, hyphenated name, containing `agents/`, `skills/` and a `README.md` modeled on `core/README.md`.
2. Add the section to the table in the root `README.md` and in `README.es.md`.

A section holds what is specific to one stack. Anything that applies regardless of stack goes in `core`.

## The two READMEs

`README.md` and `README.es.md` are the same document in English and in Spanish. Change them together, section by section, so neither says something the other does not. Each links to the other on its first line after the title. Everything else in the repo is written in English.

## Section README rows

```markdown
| [name](agents/name.md) | One-line summary of what it does |
| [name](skills/name/SKILL.md) | One-line summary of what it does |
```

## Commits

One line and nothing else: `<type>: <description>`.

- The type is one of `build` `chore` `ci` `docs` `feat` `fix` `perf` `refactor` `revert` `style` `test`.
- No scope and no `!` marker. The description starts lowercase and has no trailing period. 72 characters at most.
- No body, no footers and no trailers. Never add a `Co-Authored-By:` line or any other attribution.

Commits are signed. Never pass `--no-gpg-sign`, and never bypass a git hook with `--no-verify`.

The hooks are committed in `.githooks/`: `commit-msg` enforces this convention and `pre-push` refuses unsigned commits. A clone runs neither until `git config core.hooksPath .githooks` is run in it. `.githooks/README.md` covers the setup, here and in any repository the hooks are copied to.

`.githooks/commit-msg` and `core/skills/git-commit-hook/assets/commit-msg` are the same file, kept in two places so the skill stays self-contained when it is copied. Change them together. A change under `.githooks/` runs on the machine of everyone who has turned the hooks on, so review it as code.

## Before finishing

- Validate each skill you added or changed: `agentskills validate <section>/skills/<name>`. The CLI comes from `pip install skills-ref`; install it in a virtual environment.
- Check that the section `README.md` lists every agent and skill in the section and nothing that was removed.
- Check that no name is used twice: `grep -rh '^name:' --include='*.md' . | sort | uniq -d` prints nothing.
- If you changed a hook, check that the two copies still match: `cmp .githooks/commit-msg core/skills/git-commit-hook/assets/commit-msg` prints nothing.
- If you changed `pixelkit.py`, check that its copies still match: `for f in pixel-art/skills/*/scripts/pixelkit.py; do cmp "$f" pixel-art/skills/pixel-art-palette/scripts/pixelkit.py; done` prints nothing.