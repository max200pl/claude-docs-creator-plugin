# claude-docs-creator

Claude Code plugin for authoring, validating, and maintaining `.claude/` documentation in any project. Optimized for **context compression** — scoped rules load only when relevant, so sessions stay small even on large repos.

## Install

### As a plugin via marketplace (recommended for teams)

The repo IS the marketplace — one command subscribes, second command installs:

```bash
# Inside any Claude Code session:
/plugin marketplace add github:max200pl/claude-docs-creator
/plugin install claude-docs-creator@docs-toolkit
```

Updates later:

```bash
/plugin marketplace update docs-toolkit
```

### As a plugin via local clone (for development)

```bash
git clone https://github.com/max200pl/claude-docs-creator ~/Projects/claude-docs-creator
claude --plugin-dir ~/Projects/claude-docs-creator
```

Skills are available as `/claude-docs-creator:<skill>` in every session after install.

### Without install (ad-hoc, session-local)

Attach the toolkit as an additional directory per-session:

```bash
cd ~/Projects/my-app
claude --add-dir ~/Projects/claude-docs-creator
```

## Skills (public — shipped with plugin)

| Command | Scope | What it does |
| ---- | ---- | ---- |
| `/init-project <path>` | API | Detect stack, discover modules, scaffold `.claude/` + `CLAUDE.md` |
| `/create-docs <type> [name]` | API | Scaffold a rule, skill, agent, settings, or doc file |
| `/update-docs <path> [mode]` | API | Detect drift, refresh docs, move misplaced content |
| `/validate-claude-docs <path> [fix]` | API | Audit `.claude/` structure + auto-fix trivial issues |
| `/status <path>` | API | Health dashboard (coverage, staleness, stats) |
| `/create-mermaid <type>` | Shared | Theme-agnostic Mermaid diagram |
| `/research <topic>` | Shared | Web research → structured report in `docs/research-*.md` |
| `/create-steps <topic>` | Shared | Step-by-step runbook with rollback |
| `/create-tutorial <topic>` | Shared | ELI5 tutorial (beginner / intermediate / reference) |

Invocation after install: `/claude-docs-creator:<command>` (plugin namespace).

Maintainer-only skills — not shipped with the plugin, live in `.claude/skills/` of this repo: `/sleep` (lint toolkit), `/distill` (session retrospective), `/menu` (command index).

## What's Inside

```text
.claude-plugin/plugin.json       ← plugin manifest
skills/<name>/SKILL.md           ← 9 public skills (api + shared)
agents/<name>.md                 ← 3 specialist subagents
rules/<name>.md                  ← style + process rules (paths:-scoped)
hooks/hooks.json + *.sh          ← Pre/Post-tool-use + Stop hooks
docs/*.md + .mmd                 ← how-tos, tutorials, references, research
sequences/*.mmd                  ← flow diagrams (source of truth per skill)
output-styles/toolkit-concise.md
agents-sdk/doc-validator/        ← headless CI validator via Agent SDK
CLAUDE.md                        ← toolkit's own project instructions

.claude/skills/<name>/SKILL.md   ← 3 internal skills — maintainer-only,
                                   not packaged with the plugin
.claude/state/                   ← local session state (gitignored)
```

## Why context compression matters

A typical 20-module project generates 500+ lines of docs. If everything lives in `CLAUDE.md`, Claude pays the full cost every session — even when editing one file.

This toolkit enforces a split:

- `CLAUDE.md` under 200 lines — loads every session (project goal, stack, commands)
- `rules/<module>.md` with `paths:` globs — loads only when Claude touches matching files
- `docs/` — reference prose, loads on demand when a skill explicitly reads it

Measured savings on real monorepos: **40-80% context reduction** per session.

## Companion: SDK agent

For headless CI (GitHub Actions, pre-commit), use the Agent SDK wrapper:

```bash
cd agents-sdk/doc-validator
npm install
npm run validate -- /path/to/target-project
```

Exit code: `0` clean · `1` errors · `2` warnings · `3` setup error.

## Official docs

- [Claude Code plugins](https://code.claude.com/docs/en/plugins)
- [`.claude/` directory spec](https://code.claude.com/docs/en/claude-directory)
- [Skills](https://code.claude.com/docs/en/skills)
- [Sub-agents](https://code.claude.com/docs/en/sub-agents)
- [Hooks](https://code.claude.com/docs/en/hooks)
- [Agent SDK](https://code.claude.com/docs/en/agent-sdk/overview)

## License

MIT
