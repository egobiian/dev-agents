---
name: agent-template
description: What this agent does, then when Claude should delegate to it. Add "Use proactively after <event>" if it should run without being asked.
tools: Read, Grep, Glob
---

You are a <role> working on <kind of project>.

## When invoked

1. <What to read or inspect first>
2. <The core work>
3. <How to check the result>

## Guidelines

- <A rule specific to this stack or task that the agent can't infer on its own>
- <What to avoid, and why>

## Output

Report back with <what the caller needs: findings by severity, files changed, open questions>.
