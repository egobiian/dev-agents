# dev-agents

**English** · [Español](README.es.md)

A collection of AI agents and skills for software development, organized by stack, to copy into your own projects as plain files. It is under development: sections, names and contents may still change.

## Sections

| Section | For |
| :- | :- |
| [core](core/README.md) | Any project: git workflow and pre-commit checks |
| [astro](astro/README.md) | [Astro](https://astro.build) projects |
| [godot](godot/README.md) | [Godot](https://godotengine.org) game projects |
| [pixel-art](pixel-art/README.md) | Pixel art for games: style guide, palette, drawing and checks |
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

## Get the git hooks with curl

Run this from the root of your repository. It copies the two git hooks this repository uses into `.githooks/` and tells git to run them:

```bash
curl -fsSL https://codeload.github.com/egobiian/dev-agents/tar.gz/refs/heads/main \
  | tar -xz --strip-components=1 dev-agents-main/.githooks
git config core.hooksPath .githooks
```

`commit-msg` rejects any commit message that is not one line of the form `<type>: <description>`, and `pre-push` rejects commits with no signature. What each one expects is in [.githooks/README.md](.githooks/README.md), which is copied along with them.

## Adding to the collection

The conventions for adding agents, skills and sections are in [AGENTS.md](AGENTS.md).

## License

[MIT](LICENSE)
