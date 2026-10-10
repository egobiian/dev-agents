# dev-agents

A collection of AI agents and skills for software development, organized by stack, to copy into your own projects as plain files. It is under development: sections, names and contents may still change.

## Sections

| Section | For |
| :- | :- |
| [core](core/README.md) | Any project: git workflow and pre-commit checks |
| [astro](astro/README.md) | [Astro](https://astro.build) projects |
| [python](python/README.md) | Python projects |

Each section has an `agents/` folder with [Claude Code subagents](https://code.claude.com/docs/en/sub-agents) and a `skills/` folder with skills in the [Agent Skills](https://agentskills.io/specification) format. Its `README.md` lists what is inside.

## Get a section with curl

Run this from the root of your project. It copies the agents and skills of one section into `.claude/`:

```bash
mkdir -p .claude
curl -fsSL https://codeload.github.com/egobiian/dev-agents/tar.gz/refs/heads/main \
  | tar -xz -C .claude --strip-components=2 \
    dev-agents-main/core/agents dev-agents-main/core/skills
```

Replace `core` with the section you want, and `.claude` with another destination such as `~/.claude` to have them in all your projects. The files arrive as plain copies with no link to this repository. Run the command again to update them.

## Adding to the collection

The conventions for adding agents, skills and sections are in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
