# claude-docs-creator

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE) [![Version](https://img.shields.io/badge/version-0.15.0-green.svg)](.claude-plugin/plugin.json)

Claude Code plugin for authoring, validating, and maintaining `.claude/` documentation in any project. Optimized for **context compression** — scoped rules load only when relevant, so sessions stay small even on large repos.

## Install

```bash
# Marketplace (recommended)
/plugin marketplace add github:max200pl/claude-docs-creator
/plugin install claude-docs-creator@docs-toolkit

# Local clone (development)
git clone https://github.com/max200pl/claude-docs-creator ~/Projects/claude-docs-creator
claude --plugin-dir ~/Projects/claude-docs-creator
```

After install, skills are available as `/claude-docs-creator:<skill>`.

**Headless CI** — validate docs in GitHub Actions without an interactive session:

```bash
cd agents-sdk/doc-validator && npm install
npm run validate -- /path/to/project   # exit 0 clean · 1 errors · 2 warnings
```

## Skills

### Project docs

| Command | What it does |
| ---- | ---- |
| `/init-project <path>` | Detect stack, discover modules, scaffold `.claude/` + `CLAUDE.md` |
| `/create-docs <type> [name]` | Scaffold a rule, skill, agent, settings, or doc file |
| `/update-docs <path>` | Detect drift between code and docs, refresh and auto-fix |
| `/validate-claude-docs <path>` | Audit `.claude/` structure; pass `fix` to auto-fix trivial issues |
| `/status <path>` | Health dashboard — coverage, staleness, stats |
| `/create-sequences <name>` | Author a Mermaid sequence diagram in `.claude/sequences/` |
| `/check-links [path]` | Scan `.md`/`.mmd` for broken cross-refs (also runs as a PostToolUse hook) |
| `/menu` | Discovery screen — all available commands + quick project status |
| `/create-steps <topic>` | Step-by-step runbook with rollback instructions |

### Frontend analysis

| Command | What it does |
| ---- | ---- |
| `/analyze-frontend [path]` | Read-only — detect frontends + two-wave fan-out; writes `frontend-analysis.json` |
| `/create-frontend-docs` | Materialize JSON as `component-creation-template.md` + references + CLAUDE.md update |
| `/update-frontend-docs <area>` | Targeted refresh of one area (design-system / components / data-flow / architecture / framework-idioms / template) |

### API contracts

| Command | What it does |
| ---- | ---- |
| `/analyze-api-contracts [path]` | Read-only — detect every communication boundary (HTTP/GraphQL/gRPC/WS/SSE/queues/custom) via two-wave fan-out; writes `api-contracts-analysis.json` |
| `/create-api-contracts-docs` | Materialize JSON as `reference-api-contracts.md` + per-boundary sequence diagrams + optional CLAUDE.md update |
| `/update-api-contracts-docs <area>` | Targeted refresh — accepts boundary ID, axis (http/auth/realtime/errors), or any doc name |
| `/create-api-contract [name]` | Spec-first wizard — design a new contract from scratch (HTTP / GraphQL / WS / custom); writes `contract-<name>.md` + sequence diagram |

## Why context compression matters

A typical 20-module project generates 500+ lines of docs. If everything lives in `CLAUDE.md`, Claude pays the full cost every session.

This toolkit enforces a split:

- `CLAUDE.md` under 200 lines — loads every session
- `rules/<module>.md` with `paths:` globs — loads only when Claude touches matching files
- `docs/` — reference prose, loaded on demand by skills

Measured savings on real monorepos: **40-80% context reduction** per session.

---

MIT © Maksym Poskannyi — see [LICENSE](LICENSE)
