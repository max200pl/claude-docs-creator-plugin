---
name: init-project
scope: api
description: "Initialize .claude documentation for a project — creates CLAUDE.md, settings, and folder structure"
user-invocable: true
argument-hint: "[modules-path]"
---

# Initialize Project Documentation

> **Flow:** read all files in `sequences/init-project/` — the sequence diagrams are the source of truth for execution order
> Strategy guide: read `docs/reference-context-compression.md`
> Reference: read `docs/how-to-create-docs.md`
> Phase reference: read `docs/reference-init-project-phases.md`
> Style rules: read `rules/markdown-style.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

Set up `.claude/` folder structure, detect the project, and create an ideal `CLAUDE.md`. Rules are NOT created here — they require deeper understanding and are added later via `/create-docs rule`.

## What `/init-project` creates

- `.claude/` folder structure (`rules/`, `docs/`, `skills/`, `sequences/`, `agents/`, `output-styles/` + `.gitkeep`)
- `CLAUDE.md` — project overview (under 200 lines, with `@path` imports)
- `CLAUDE.local.md` — empty personal overrides (gitignored)
- `.claude/settings.json` — stack-specific permissions
- `.claude/settings.local.json` — empty personal settings (gitignored)
- `.gitignore` entries — `CLAUDE.local.md`, `settings.local.json`, `agent-memory-local/`, `.claude/state/`
- Per-module `CLAUDE.md` — one per non-trivial module (under 60 lines each)
- `.claude/state/reports/init-project-<ts>.md` — run report per [rules/report-format.md](../../rules/report-format.md) (gitignored)

## What `/init-project` does NOT create

- Project-specific rules (use `/create-docs rule` after you understand the project patterns).
- Skills (project-specific skills are rare)
- Sequence diagrams (use `/create-mermaid` for data flow diagrams)

## Usage

`/init-project [modules-path]`

- `/init-project` — auto-detect structure and project type
- `/init-project projects/` — specify where modules live
- `/init-project src/packages` — monorepo packages directory

## Interactive Wizard

This skill runs as a guided wizard — not a silent batch job. At key checkpoints, pause and ask the user to confirm or correct before proceeding.

**Documentation language policy:**

- **This toolkit's own files** (plugin code: `rules/`, `skills/**/SKILL.md`, `agents/`, `sequences/`, `docs/`, `hooks/`) — always English. Enforced by a toolkit-internal rule (`docs-english-only.md`) that ships only in the dev repo, not in the plugin package.
- **Target-project generated content** (root `CLAUDE.md`, module `CLAUDE.md`, project rules and docs the skill writes into the user's project) — **English is the default and strongly recommended** (grep-ability, tool compatibility, cross-team readability, LLM instruction reliability). **May be overridden** if the user's team operates in another language — ask at the language checkpoint in that case.
- **User-Claude conversation** — any language the user chooses, always.

When to ask about language:

- If the existing project already has a `CLAUDE.md` or README in a non-English language → **ask** whether to match that language or switch to English.
- If the project has no pre-existing docs and nothing signals a non-English team → **default to English without asking**.
- If the user explicitly requests non-English at skill start → honor it, no question needed.

When the user picks non-English, record the choice in the `## Notes` section of the run report (`doc_language=<code>`) so subsequent `/update-docs` runs can inherit the choice.

**Checkpoints** (marked with `Claude->>User` in the sequence diagram):

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Detect stack | Detected language, framework, tooling | Correct? Override? |
| Classify type | Single-stack / monorepo / feature monorepo | Confirm? |
| Discover modules | Table of modules with file counts | Add / remove? |
| Doc language (only if non-English signal detected) | Detected or suggested language | English (default) / other? |
| Create CLAUDE.md | Line count, architecture summary | Review? Test build commands? |
| Report | Dashboard with next steps + saved report path | What rules to add first? |

**Not to ask** (determined by rules or previously-detected state): whether to create `.claude/` (always yes), where to put files (always per the paths documented in `what this skill creates`).

**Format for checkpoints:**

```text
╭─ Detected Stack ────────────────────────────────────────────╮
│                                                             │
│  Language      TypeScript                                   │
│  Framework     Next.js 14                                   │
│  Package mgr   pnpm                                         │
│  Formatter     Prettier (.prettierrc)                       │
│  Linter        ESLint (.eslintrc.json)                      │
│  Tests         Jest (jest.config.ts)                        │
│  CI            GitHub Actions                               │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
Is this correct? (confirm / correct)
```

If the user says nothing specific, take "confirm" as default and proceed.

## Reference

Phase-by-phase implementation details: [`docs/reference-init-project-phases.md`](../../docs/reference-init-project-phases.md)
