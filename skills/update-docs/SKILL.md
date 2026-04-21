---
name: update-docs
scope: api
description: "Update and refresh an existing .claude/ directory in a target project — detects drift between code and docs, then orchestrates /status, /validate-claude-docs, and targeted regeneration to bring docs back in sync."
user-invocable: true
argument-hint: "<project-path> [mode]"
---

# Update .claude Documentation

> Preflight: follow `rules/api-skill-preflight.md` before running any check
> **Flow:** read `sequences/update-docs.mmd` — the sequence diagram is the source of truth for execution order
> Reference guide: read `docs/how-to-create-docs.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

Orchestrator skill. Refreshes a target project's `.claude/` when code has drifted away from the docs. Composes two existing skills and adds one unique phase (drift detection) — it does not duplicate their logic.

Use this after significant code changes when `/init-project` already ran once. Do NOT use on a fresh project — use `/init-project` instead.

## Usage

```text
/update-docs <project-path>                         # interactive: per-item confirmation
/update-docs <project-path> auto                    # apply safe updates without asking
/update-docs <project-path> report                  # dry-run, write nothing
/update-docs <project-path> --refresh frontend      # refresh ALL frontend artefacts
/update-docs <project-path> --refresh frontend:design-system   # refresh one frontend area
/update-docs <project-path> --refresh frontend:components
/update-docs <project-path> --refresh frontend:data-flow
/update-docs <project-path> --refresh frontend:architecture
```

If `<project-path>` is omitted, ask the user. Do not default to the toolkit's own cwd.

## `--refresh` Flag

The `--refresh frontend[:<area>]` flag is a thin delegation to `/analyze-frontend` — it re-runs frontend analysis without going through the full drift-detection pipeline of the default mode. Use when you KNOW a specific frontend area drifted (e.g., you just changed `tailwind.config.ts` → refresh `design-system`).

| Invocation | Effect |
| ---- | ---- |
| `--refresh frontend` | Delegate to `/claude-docs-creator:analyze-frontend` (all 5 specialists) |
| `--refresh frontend:design-system` | Delegate to `/claude-docs-creator:analyze-frontend --only design-system` |
| `--refresh frontend:components` | Delegate to `/claude-docs-creator:analyze-frontend --only components` |
| `--refresh frontend:data-flow` | Delegate to `/claude-docs-creator:analyze-frontend --only data-flow` |
| `--refresh frontend:architecture` | Delegate to `/claude-docs-creator:analyze-frontend --only architecture` |

When `--refresh` is set, `/update-docs` SKIPS its own phases (Inventory / Validate / Detect-drift / Plan / Apply / Verify / Report) and invokes `/analyze-frontend` directly. The target `/analyze-frontend` run produces its own report at `.claude/state/reports/analyze-frontend-<ts>.md`.

Mode flag (`auto` / `report`) combines with `--refresh`:

- `--refresh frontend report` → `/analyze-frontend` runs but writes NO artefacts (plans only)
- `--refresh frontend auto` → `/analyze-frontend` runs non-interactively, accepts all detected roots and writes

If `--refresh` is set AND `<project-path>/.claude/` is missing, abort with "run `/init-project` first".

## Modes

| Mode | Confirmation | Writes |
| ---- | ---- | ---- |
| `report` | n/a | never |
| (default) interactive | per-item prompt | after user approves |
| `auto` | skipped for safe items | still prompt on destructive |

Even in `auto`, always prompt before: deleting orphan module CLAUDE.md, overwriting user-customized sections, removing rules whose `paths:` now match zero files.

Pass the mode into the preflight's confirmation box so the user sees it.

## Composition

This skill is a pipeline: two delegated phases + four unique phases + one delegated verify + one unique Report.

| Phase | Owner | Responsibility |
| ---- | ---- | ---- |
| Inventory | `/status` | Gather stats, coverage, staleness — read-only |
| Validate | `/validate-claude-docs` (with `fix` unless mode=report) | Universal checks + trivial auto-fixes |
| Detect drift | **this skill** | Compare code vs docs — unique to `/update-docs` |
| Build update plan | **this skill** | Classify drift items by safety class |
| Confirm with user | **this skill** | Interactive / auto / report gating |
| Apply drift updates | **this skill** | Write drift-specific fixes only |
| Verify | `/validate-claude-docs` (no fix) | Confirm post-state is clean |
| Report | **this skill** | Persist the run dashboard to `.claude/state/reports/update-docs-<ts>.md` per [rules/report-format.md](../../rules/report-format.md) |

Rule: never re-implement what `/status` or `/validate-claude-docs` already does. If a check belongs to either — add it there, not here.

**Naming note:** the `report` *mode* (dry-run, see Modes table above) is different from the *Report phase*. The phase runs in every mode — it writes a persistent copy of the dashboard to `.claude/state/reports/` (gitignored). `report` mode controls whether drift fixes are applied; it does not suppress the report file. A dry-run still produces a report showing what WOULD have been applied — that's the point.

## Reference

The sequence diagram defines order. Sections below describe only the **unique** phases. Delegated phases follow the behavior of their owning skills.

### Phase: Detect drift (unique)

Compare the current code tree against what the docs claim. Read-only — produce a drift report, do not write anything yet.

Full detection logic per kind: `docs/reference-drift-catalog.md`. The map below lists kinds the phase scans for:

| Kind | Refresh target |
| ---- | ---- |
| `stack`, `build-commands` | Build & Run in CLAUDE.md |
| `modules` | New/orphan module CLAUDE.md |
| `directory-tree` | Project Structure section |
| `rule-paths` | Rule frontmatter |
| `path-imports` | `@path` imports in CLAUDE.md |
| `non-canonical-subdirs` | Move plan to `docs/` / `skills/<x>/…` |
| `claude-md-rule-dup` | Slim recipe (pointer, not auto) |
| `mermaid-in-docs`, `mermaid-in-rules-or-agents` | Extract to `sequences/<name>.mmd` |
| `rule-shaped-in-docs`, `claude-md-section-without-rule` | Promote / generate rule |
| `skill-without-mmd` | Generate `.mmd`, add Flow marker |
| `misplaced-by-content` | Move to canonical home |

Present as a drift summary box:

```text
  ┌─ Drift ───────────────────────────────────────────────────┐
  │                                                           │
  │  Stack            ⚠  CLAUDE.md says "Node 18",            │
  │                      actual: Node 20 (.nvmrc)             │
  │  Modules          +2 new (auth, notifications)            │
  │                   -1 removed (legacy-api)                 │
  │  Rule paths       ✗  rules/api.md → src/api/**/*.py       │
  │                      matches 0 files                      │
  │  Build commands   ✓  unchanged                            │
  │  Orphan imports   ⚠  CLAUDE.md @docs/old.md (missing)     │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

### Phase: Build update plan (unique)

Classify every drift item into a safety class. Validation issues already resolved by the delegated validate phase are excluded — do not double-apply.

| Class | Applied when | Examples |
| ---- | ---- | ---- |
| `safe-auto` | applied in `auto` mode without prompting | refresh Build & Run, fix dead `@path` import, extract large embedded `.mmd` to `sequences/` (replace with pointer, content preserved) |
| `needs-review` | always prompt | new module CLAUDE.md content, `paths:` glob rewrite, promote rule-shaped doc → `rules/`, generate new rule from CLAUDE.md section, move misplaced file |
| `destructive` | always prompt with explicit approval | delete orphan module CLAUDE.md, remove rule, delete original doc after rule promotion |

### Phase: Confirm with user (unique)

In interactive mode, show the plan as a checklist and accept per-item choices:

```text
╭─ Update plan ───────────────────────────────────────────────╮
│                                                             │
│  [a] apply all safe, prompt on rest                         │
│  [s] skip item                                              │
│  [d] show diff                                              │
│  [q] cancel                                                 │
│                                                             │
│  1. [review]      Refresh Build & Run (Node 18 → Node 20)   │
│  2. [review]      Add CLAUDE.md for new module `auth`       │
│  3. [review]      Add CLAUDE.md for new module `notif`      │
│  4. [destructive] Delete orphan CLAUDE.md (legacy-api)      │
│  5. [review]      Rewrite paths: in rules/api.md            │
│  6. [safe]        Remove dead @path docs/old.md             │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
Choose: [a] / number / [q]
```

In `auto` mode, skip prompt for `safe-auto`, still prompt for `needs-review` and `destructive`.

In `report` mode, print the plan and exit — do not apply anything.

### Phase: Apply drift updates (unique)

Full per-step procedure, verification, rollback: `docs/reference-drift-repairs.md`.

Order (least-destructive first):

1. `@path` import repairs
2. Build & Run / Project Structure refresh
3. New module CLAUDE.md generation
4. Rule `paths:` updates (user confirms glob preview)
5. Content placement repairs (Mermaid extract, rule promote, rule generate, misplaced move)
6. Deletions (explicit approval)

Invariants:

- After each write, re-read to verify parse. If final verify reports `[ERR]` on a file written this session → revert and flag.
- Never overwrite handwritten `Patterns` / `Anti-patterns` / `Rules` sections in a module CLAUDE.md. New module → generate full. Existing module with file-count drift → refresh only header / Dependencies.

### Phase: Report (unique)

Writes a persistent run report to `.claude/state/reports/update-docs-<ts>.md` per [rules/report-format.md](../../rules/report-format.md). Runs in every mode (`report`, `interactive`, `auto`).

**Timing capture — required for wall-clock metric:**

At the very start of the preflight (before the Inventory phase begins), capture start timestamp:

```bash
Bash: START_TS=$(date +%s); RUN_TS=$(date -u +%Y%m%dT%H%M%SZ); DISPLAY_TS=$(date +%Y%m%d-%H%M%S); echo "START_TS=$START_TS RUN_TS=$RUN_TS DISPLAY_TS=$DISPLAY_TS"
```

Preserve through the run. **REQUIRED** — capture per-phase timestamps at each phase boundary. Pattern:

```bash
# Phase start:
Bash: PHASE_<NAME>_START=$(date +%s)
# Phase end:
Bash: PHASE_<NAME>_END=$(date +%s); PHASE_<NAME>_SEC=$((PHASE_<NAME>_END - PHASE_<NAME>_START))
```

Phases to time: `INVENTORY`, `VALIDATE`, `DETECT_DRIFT`, `BUILD_PLAN`, `CONFIRM`, `APPLY`, `VERIFY`, `REPORT`. Missing timings are acknowledged in `## Notes` as `timing_missing=<phase>`, never estimated.

**Report generation (this phase):**

```bash
Bash: END_TS=$(date +%s); echo "wall_clock_sec=$((END_TS-START_TS))"
```

Then collect:

- Mode used (`report` / `interactive` / `auto`)
- Drift kinds found, per-kind counts
- Classification outcomes: N safe-auto, N needs-review, N destructive
- Per-class counts of what was actually applied vs. skipped vs. user-rejected
- Artefacts: every file modified, created, or deleted — with line counts for created/modified (use `wc -l`)
- Validation findings from delegated `/validate-claude-docs` (pre and post)
- Next-step recommendations (same as on-screen dashboard)

Write the report file at `<project-root>/.claude/state/reports/update-docs-<DISPLAY_TS>.md`. Create `.claude/state/reports/` if it doesn't exist.

**REQUIRED — exact first-line format** (not negotiable, do NOT use JSON, do NOT rename keys):

```text
<!-- report: skill=update-docs ts=<ISO-UTC> wall_clock_sec=<int> modules=<int> artefacts=<int> mode=<report|interactive|auto> drift_items=<int> -->
```

Hard rules:

- **Prefix is literal `<!-- report: `** — NOT `<!-- meta: `, not `<!-- run: `.
- **Format is `key=value` pairs separated by spaces** — NOT a JSON object.
- **Key names exactly** — `ts` (NOT `run_ts`), `wall_clock_sec`, `modules`, `artefacts` (NOT `artefact_count`), `mode`, `drift_items`. Optional extras like `validator_fixes=<int>` allowed AFTER the required keys.
- Single line; no quoted values unless the value contains spaces.

See [rules/report-format.md](../../rules/report-format.md) as source of truth — this skill's instruction above must match it.

**Report file vs on-screen dashboard:**

- On-screen dashboard (see Output section below) uses box-drawing per `rules/output-format.md`
- Report file uses plain markdown per `rules/report-format.md` — same content, different rendering

Append the saved report path as the last line of the on-screen output so the user knows where to find the persistent copy.

## Output

Preflight box, then sections grouped by outcome, then summary.

```text
╭─ /update-docs ──────────────────────────────────────────────╮
│                                                             │
│  Target       ~/Projects/my-app                             │
│  Mode         interactive / auto / report                   │
│                                                             │
╰─────────────────────────────────────────────────────────────╯

  ┌─ Inventory (from /status) ────────────────────────────────┐
  │  CLAUDE.md 42 lines, 5 rules, 3 skills, 0 stale           │
  └───────────────────────────────────────────────────────────┘

  ┌─ Validation (from /validate-claude-docs fix) ─────────────┐
  │  [FIX]  rules/api.md — trailing newline                   │
  │  [FIX]  CLAUDE.md — kebab-case frontmatter                │
  └───────────────────────────────────────────────────────────┘

  ┌─ Drift applied ───────────────────────────────────────────┐
  │  [UPDATED]  CLAUDE.md — Build & Run refreshed (Node 20)   │
  │  [CREATE]   auth/CLAUDE.md — new module                   │
  │  [CREATE]   notifications/CLAUDE.md — new module          │
  │  [DELETE]   legacy-api/CLAUDE.md — orphan, approved       │
  │  [UPDATED]  rules/api.md — paths: rewritten               │
  └───────────────────────────────────────────────────────────┘

  ┌─ Skipped / needs review ──────────────────────────────────┐
  │  [SKIP]  rules/style.md — user said skip                  │
  │  ⚠  rules/db.md — paths: matches 0 files; module gone?    │
  └───────────────────────────────────────────────────────────┘

  ┌─ Final verify (from /validate-claude-docs) ───────────────┐
  │  ✓  clean — 0 errors, 0 warnings                          │
  └───────────────────────────────────────────────────────────┘

───
12 files scanned, 2 validator fixes, 5 drift updates, 1 skipped,
1 needs review — 34s total
Report saved: .claude/state/reports/update-docs-20260421-143022.md
```

## What This Skill Does NOT Do

- Duplicate `/status` or `/validate-claude-docs` logic — always delegate
- Rewrite user-authored module CLAUDE.md sections (patterns, anti-patterns, rules)
- Change skills, agents, or `settings.json` — edit those directly or via `/create-docs`
- Create new rules — use `/create-docs rule`
- Run a full `/init-project` — if `.claude/` is absent, stop and suggest `/init-project` instead
