---
name: update-registry
description: "Targeted edit of one registry entry without a full re-analysis. Supports rename, move (path change), retype (primitive ↔ feature ↔ local), set parent, set Figma metadata, set status. Cascades name changes through every entry's uses[] and parent fields. Does NOT touch source code — only registry. Use when source files are already moved/renamed and registry needs to catch up; or when promoting a type:local entry to a primitive."
scope: api
argument-hint: "<name> [--rename <new-name>] [--move <new-path>] [--type <primitive|feature|local>] [--parent <name|null>] [--status <enum>] [--figma-node <id>] [--figma-file <key>] [--dry-run]"
allowed-tools: [Read, Write, Edit, Bash]
---

# Update Registry

> **Registry schema:** `rules/registry-schema.md` (canonical allow-list) + `plugins/docs-creator/docs/reference-frontend-analysis-schema.md` § Component Registry Schema (M13 1.4 lifecycle)

Single-entry edit. Resolves the entry by `<name>` (the positional arg), applies the requested field changes, and cascades any rename through all dependents' `uses[]` + `parent` fields.

## Usage

```text
# Rename Button → AppButton (cascades through every uses[] mention)
/component-creator:update-registry Button --rename AppButton

# Move a file's path after a refactor
/component-creator:update-registry IconBadge --move src/shared/ui/icon-badge/icon-badge.js

# Promote a local component to primitive (also clears parent)
/component-creator:update-registry CardHeader --type primitive --parent null

# Refresh Figma mapping after manual re-link
/component-creator:update-registry PrimaryCTA --figma-node 1234:5678 --figma-file abcXYZ

# Mark a known-bad entry as stale (keep audit trail; do not delete)
/component-creator:update-registry LegacyDialog --status stale

# Preview the full set of changes (incl. cascades) without writing
/component-creator:update-registry Button --rename AppButton --dry-run
```

Multiple flags may be combined in a single invocation. All edits are atomic — either all succeed or none are written.

## When to use

- Source files were moved/renamed (e.g. via IDE refactor) — sync registry without re-scanning the whole codebase
- An entry was misclassified (`type: feature` should be `primitive`)
- Promoting a `type: local` entry: appeared in `uses[]` of multiple parents (`/validate-registry` flagged it as `PROMOTION_CANDIDATE`)
- Figma file was restructured — `/sync-registry` flagged `newly_disconnected`; user manually re-links
- Quick status correction (e.g. flipping `pending` → `done` after manual verification)

NOT for adding new components (`/create-component`), removing entries (`/remove-component`), or doing visual verification (`/update-component --verify`).

## Execution

### ⚙ Version check — OUTPUT BANNER FIRST per UserPromptSubmit hook

### Step 0 — Preflight (MANDATORY)

**0.1 TodoWrite** — call FIRST:

```text
☐ 0  Preflight
☐ 1  Resolve target entry by <name>
☐ 2  Validate proposed changes against schema
☐ 3  Compute cascade (rename → uses[] + parent)
☐ 4  Apply (skip if --dry-run)
☐ 5  Report
```

**0.2 Read inputs:**

- `.claude/state/component-registry.json` — REQUIRED. Missing → stop with "No registry. Run `/docs-creator:analyze-frontend` or `/component-creator:create-component <name>` first."
- Positional `<name>` — REQUIRED
- At least ONE edit flag — required (else "nothing to update; pass at least one of --rename, --move, --type, --parent, --status, --figma-node, --figma-file")

### Step 1 — Resolve target entry

Find the entry with `name == <name>`. If not found → stop with:

```text
No entry named "<name>" in registry. Closest matches: <name1>, <name2>, <name3>.
Use /validate-registry to list all entries.
```

If multiple entries share the same `name` (registry has a `NAME_COLLISION` — see `/validate-registry`) → stop, instruct user to fix collision first.

### Step 2 — Validate proposed changes

For each provided flag, validate the new value:

| Flag | Validation |
| ---- | ---- |
| `--rename <new>` | Must be PascalCase; must NOT collide with any existing entry's `name` (other than the target itself) |
| `--move <path>` | Must be a relative path; must NOT collide with any other entry's `path`; warn (not error) if file does not yet exist on disk (user may be mid-refactor) |
| `--type <T>` | Must be one of `primitive`, `feature`, `local` |
| `--parent <name\|null>` | If non-null: must resolve to an existing entry; if target's new `--type` is not `local`, parent MUST be null |
| `--status <S>` | Must be in `{scanned-only, managed, pending, done, stale, in-progress, needs-review, unverified}` |
| `--figma-node <id>` | Plain string; no parse |
| `--figma-file <key>` | Plain string; no parse |

If any flag value violates schema → emit `[ERR] <field>: <reason>` and stop. Do NOT partial-apply.

### Step 3 — Compute cascade (rename only)

If `--rename` was passed:

1. For every entry in registry with `<old-name>` in its `uses[]` → record a planned edit replacing that string with `<new-name>`
2. For every entry with `parent == <old-name>` → record a planned edit setting `parent = <new-name>`
3. If the target itself is `type: local` AND its `parent` is being renamed in the same call — not possible (we're renaming target, not parent)

Build a cascade summary:

```text
Cascade for rename Button → AppButton:
  ✎ Update target entry: name Button → AppButton
  ✎ Entry "PrimaryCTA": uses[] [Button, Icon] → [AppButton, Icon]
  ✎ Entry "SecondaryCTA": uses[] [Button] → [AppButton]
  ✎ Entry "CardHeader": parent Button → AppButton
  3 dependents affected
```

For `--type` change from `local → primitive`:

- If the target had `parent != null`: clear `parent = null` automatically (consistency)
- Note in cascade report: `Promoting local → primitive: cleared parent reference "<old-parent>"`

For `--move`: only affects the target entry's `path` — no cascade. Other entries reference target by `name`, not by `path`.

### Step 4 — Apply (skip if `--dry-run`)

If `--dry-run`: print cascade summary, DO NOT write. Stop with `[DRY-RUN] no changes written`.

Otherwise:

1. Apply target-entry edits in memory
2. Apply cascade edits in memory
3. Validate all edited entries against schema (defense in depth — same allow-list check as `/validate-registry` Step 4)
4. If any post-edit entry violates schema → stop, do NOT write, emit `[INTERNAL] post-edit schema check failed: <reason>` (this means the skill has a bug)
5. Update `generated.ts = now()`
6. Atomic write (temp + rename)

### Step 5 — Report

Save to `.claude/state/reports/update-registry-<DISPLAY_TS>.md`. Body summary:

```text
╭─ Update Registry ───────────────────────────────────────────╮
│  Target: <name>                                             │
│                                                             │
│  Changes applied:                                           │
│    F field edits on target                                  │
│    C cascade edits across N dependents                      │
│                                                             │
│  --dry-run: <yes|no>                                        │
╰─────────────────────────────────────────────────────────────╯
```

Per-change detail in sections below. Final line: `[OK] registry updated (schema_version unchanged)` or `[DRY-RUN] no changes written`.

### Conditional behaviors

- Target not found AND user passed `--rename` → user might be trying to add; stop with "Did you mean /create-component <new-name>?"
- `--type local` passed but `--parent` not passed AND target had no parent → stop with "type:local entries require a parent. Pass --parent <ComponentName>."
- `--type primitive|feature` passed with `--parent <non-null>` → stop with "only type:local entries can have a parent"
- `--status done` passed but target has `figma_connected: false` AND user hasn't passed `--figma-node` → warn (not error) `marking done without Figma connection — consider /sync-registry first`
- Registry has any `NAME_COLLISION` or `PATH_COLLISION` from `/validate-registry` involving the target → stop, instruct user to resolve via `/validate-registry --fix` or manual edit first

## What this skill does NOT do

- Does NOT move/rename actual source files on disk — use IDE refactor or shell `mv`, then run this skill to sync registry
- Does NOT update `.figma.{ext}` Code Connect file content (use `/update-component` for that)
- Does NOT scan the codebase (use `/docs-creator:update-frontend-docs` for full re-analysis)
- Does NOT contact Figma (use `/sync-registry`)
- Does NOT run SSIM verification
- Does NOT delete entries (use `/remove-component`)
- Does NOT bulk-edit (only one entry per invocation; cascades are automatic, not user-driven)
