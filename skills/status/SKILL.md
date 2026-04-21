---
name: status
scope: api
description: "Health dashboard for a target project's .claude/ — stats, rule coverage, staleness, issues. Runs from toolkit against any project path."
user-invocable: true
argument-hint: "<project-path>"
---

# Status Dashboard

> Preflight: follow `rules/api-skill-preflight.md` before gathering any data

Deep health check of a target project's `.claude/` documentation. Runs from the toolkit (boss-mode), takes a path to the project to inspect. Shows stats, coverage gaps, stale files, and actionable issues.

## Usage

```text
/status <project-path>
```

**Examples:**

- `/status ~/Projects/GameBooster`
- `/status .` — dashboard for the current directory (when toolkit dev wants to self-check)

After preflight passes, `$TARGET` is the resolved project root. All scans below use `$TARGET/...` as the root.

## Output Format

Display as a formatted dashboard:

```text
╭─────────────────────────────────────────────────────────────╮
│  .claude Health Dashboard                                   │
╰─────────────────────────────────────────────────────────────╯
```

### Documentation stats

Scan the filesystem and display:

```text
  ┌─ Documentation ───────────────────────────────────────────┐
  │                                                           │
  │  CLAUDE.md          42 / 200 lines          ██░░░░  21%  │
  │  Rules               5 files (3 scoped, 2 global)        │
  │  Skills              7 available                          │
  │  Sequences           3 diagrams                           │
  │  Agents              1 configured                         │
  │  Docs                4 reference files                    │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

Progress bar for CLAUDE.md uses block characters:

- `█` for filled portion (lines used / 200 max)
- `░` for remaining capacity
- 6 characters wide total

### Rule coverage

Check which project directories are covered by path-scoped rules:

```text
  ┌─ Rule Coverage ───────────────────────────────────────────┐
  │                                                           │
  │  src/api/          ✓  covered by api-design.md            │
  │  src/components/   ✓  covered by components.md            │
  │  src/utils/        ✗  no rule (trivial? or missing?)      │
  │  tests/            ✓  covered by testing.md               │
  │  scripts/          ⚠  no rule (5 files — worth adding?)   │
  │                                                           │
  │  Coverage: 3/5 directories  ██████████░░  60%             │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

How to calculate:

1. Find top-level source directories (ignore `node_modules`, `.git`, `dist`, `build`, etc.)
2. For each directory, check if any rule's `paths:` glob matches files in it
3. Mark as `✓` covered, `✗` missing, `⚠` maybe-needed (5+ files, no rule)
4. Directories with under 5 files are trivial — don't flag as missing

### Skill ↔ sequence sync

Check that each skill with ordered phases has a companion sequence diagram:

```text
  ┌─ Skill ↔ Sequence Sync ──────────────────────────────────┐
  │                                                           │
  │  init-project      ✓  sequences/init-project/             │
  │  create-docs       ✓  sequences/create-docs.mmd          │
  │  create-mermaid    ✓  sequences/create-mermaid.mmd        │
  │  validate-docs     —  checklist (no sequence needed)      │
  │  sleep             —  checklist (no sequence needed)      │
  │  menu              —  single output (no sequence needed)  │
  │  status            —  single output (no sequence needed)  │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

Logic: if SKILL.md contains `> **Flow:**` reference — check the `.mmd` file exists. If not — mark as `—` (no sequence needed).

### Staleness check

Compare file modification times against git log:

```text
  ┌─ Staleness ───────────────────────────────────────────────┐
  │                                                           │
  │  Fresh (< 7 days)     12 files                            │
  │  Aging (7-30 days)     3 files                            │
  │  Stale (> 30 days)     0 files                            │
  │                                                           │
  │  Oldest: rules/api-design.md (23 days ago)                │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

Use `git log -1 --format="%cr" -- <file>` per file. Flag any `.claude/` file not modified in 30+ days as potentially stale.

### Frontend analysis artefacts

Conditional section — only shown if the project has at least one `frontend-*` artefact. If none are present, the section is omitted entirely (don't show an empty box).

Detection: glob for any of `.claude/rules/frontend-*.md`, `.claude/docs/architecture-frontend*.md`, `.claude/docs/component-inventory*.md`, `.claude/sequences/frontend-data-flow*.mmd`.

```text
  ┌─ Frontend Analysis ───────────────────────────────────────┐
  │                                                           │
  │  Design system rule    ✓  generated 4 days ago            │
  │  Component conventions ✓  generated 4 days ago            │
  │  Architecture doc      ✓  generated 4 days ago            │
  │  Component inventory   ✓  generated 4 days ago            │
  │  Data-flow diagram     ⚠  11 days old — possibly stale    │
  │                                                           │
  │  Last analyze-frontend run:                               │
  │    .claude/state/reports/analyze-frontend-20260421-...md  │
  │                                                           │
  │  Run /claude-docs-creator:update-docs . --refresh          │
  │      frontend:data-flow to refresh just the stale area    │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

How to compute:

1. Glob `.claude/rules/frontend-*.md` + `.claude/docs/architecture-frontend*.md` + `.claude/docs/component-inventory*.md` + `.claude/sequences/frontend-data-flow*.mmd`
2. For each file, get `git log -1 --format="%cr" -- <file>` (fallback to mtime if not tracked yet)
3. Mark with ✓ if fresh (under 7 days), ⚠ if aging (7-30 days), ✗ if stale (over 30 days)
4. Find most recent `.claude/state/reports/analyze-frontend-*.md` by mtime; show its relative path
5. If any artefact is stale/aging, suggest the narrow refresh command (`--refresh frontend:<area>`)

If N frontends (suffixed files like `frontend-design-system-web-app.md` + `frontend-design-system-marketing.md`): show them grouped per frontend, one sub-row per artefact.

### Issues

Run a quick validation (subset of `/validate-claude-docs`) and display:

```text
  ┌─ Issues ──────────────────────────────────────────────────┐
  │                                                           │
  │  0 errors   2 warnings   1 suggestion                    │
  │                                                           │
  │  ⚠  rules/old-style.md — no paths: (loads every session) │
  │  ⚠  CLAUDE.md — 3 {{placeholders}} remaining             │
  │  💡 Consider adding rule for src/scripts/ (8 files)       │
  │                                                           │
  │  Run /validate-claude-docs fix to resolve                 │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

Severity icons:

- `✗` or `ERR` — broken (missing files, invalid YAML, etc.)
- `⚠` or `WARN` — needs attention
- `💡` or `HINT` — suggestion for improvement

## How to Gather Data

1. **Stats**: Glob + wc -l for counts
2. **Coverage**: Glob source dirs, parse `paths:` from rules frontmatter, match
3. **Sync**: Glob skills, grep for `> **Flow:**`, check target exists
4. **Staleness**: `git log -1 --format="%at %cr" -- <file>` for each `.claude/` file
5. **Frontend artefacts**: Glob `.claude/rules/frontend-*.md`, `.claude/docs/{architecture-frontend,component-inventory}*.md`, `.claude/sequences/frontend-data-flow*.mmd`, latest `.claude/state/reports/analyze-frontend-*.md`. Section is conditional — omit if zero matches.
6. **Issues**: Quick subset of validate checks (placeholders, missing paths matches, orphan references)
