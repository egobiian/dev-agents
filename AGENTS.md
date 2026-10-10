# dev-agents

A collection of Claude Code subagents and Agent Skills, grouped into sections by stack. It is a library to browse and copy from. There is no build step, no plugin manifest and no marketplace: don't add `.claude-plugin/`, `plugin.json` or install tooling unless asked.

## Layout

```text
<section>/              one directory per stack: core (stack-agnostic), astro, ...
  README.md             index of every agent and skill in the section
  agents/<name>.md      subagents
  skills/<name>/        skills, each with a SKILL.md
templates/              starting points for new agents and skills
```

Nothing lives under `.claude/`, so nothing in this repo is active while you work on it. Consumers copy files into the `.claude/agents/` and `.claude/skills/` (or `.agents/skills/`) directories of their own projects.

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

## Adding a subagent

Subagents follow the [Claude Code subagent format](https://code.claude.com/docs/en/sub-agents).

1. Copy `templates/agent-template.md` to `<section>/agents/<name>.md` and set `name` to the filename without `.md`.
2. Write `description` as the delegation trigger: what the agent does and when Claude should hand work to it. Add "Use proactively" when it should run without being asked.
3. List only the tools the agent needs in `tools`. A read-only reviewer gets `Read, Grep, Glob`, not the full set.
4. Leave `model` out unless the agent needs a specific one. Frontmatter fields are camelCase and case-sensitive.
5. Write the body as a self-contained system prompt. A subagent receives only that body plus basic environment details, so it knows nothing about this repo or the conversation that invoked it.
6. Add a row to the section `README.md`.

## Adding a section

1. Create `<section>/` with a lowercase, hyphenated name, containing `agents/`, `skills/` and a `README.md` modeled on `core/README.md`.
2. Add the section to the tables in the root `README.md`.

A section holds what is specific to one stack. Anything that applies regardless of stack goes in `core`.

## Section README rows

```markdown
| [name](agents/name.md) | One-line summary of what it does |
| [name](skills/name/SKILL.md) | One-line summary of what it does |
```

## Before finishing

- Validate each skill you added or changed: `agentskills validate <section>/skills/<name>`. The CLI comes from `pip install skills-ref`; install it in a virtual environment.
- Check that the section `README.md` lists every agent and skill in the section and nothing that was removed.
- Check that no name is used twice: `grep -rh '^name:' --include='*.md' . | sort | uniq -d` prints nothing.
