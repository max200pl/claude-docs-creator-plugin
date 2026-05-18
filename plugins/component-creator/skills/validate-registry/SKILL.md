---
name: validate-registry
description: "Structural audit of component-registry.json. Detects missing files on disk (flags as stale), broken uses[] dependency refs, name collisions, schema violations (forbidden fields per registry-schema.md rule), and type:local promotion candidates (used by 2+ parents). Optional --fix mode auto-applies safe corrections (stale status, dedup). M13-aware: knows the scanned-only / managed / pending / done / stale status enum."
scope: api
argument-hint: "[--fix]"
allowed-tools: [Read, Write, Edit, Bash]
---

# Validate Registry

> **Registry schema:** `rules/registry-schema.md` (canonical allow-list) + `plugins/docs-creator/docs/reference-frontend-analysis-schema.md` § Component Registry Schema (M13 1.4 lifecycle enum)

Pure structural audit. Does NOT call Figma, does NOT verify SSIM, does NOT touch frontend-analysis.json. Use it to surface drift between registry and disk + internal inconsistencies.

## Usage

```text
/component-creator:validate-registry              # report only
/component-creator:validate-registry --fix        # apply safe auto-fixes (see § Step 5)
```

## When to use

- Before `/component-creator:sync-registry` — verifies the input is well-formed
- After a refactor that moved/renamed component files — surfaces stale entries
- After manual edits to `component-registry.json` — catches schema violations
- Periodically (CI or weekly) — early detection of drift

NOT for re-running visual verification (use `/update-component --verify`) or refreshing Figma state (use `/sync-registry`).

## Execution

### ⚙ Version check — OUTPUT BANNER FIRST per UserPromptSubmit hook

### Step 0 — Preflight (MANDATORY)

**0.1 TodoWrite** — call FIRST:

```text
☐ 0  Preflight
☐ 1  Load registry + parse
☐ 2  Disk existence check (per entry)
☐ 3  Dependency graph check (uses[])
☐ 4  Schema + collision audit
☐ 5  Apply --fix (skip if not passed)
☐ 6  Report
```

**0.2 Read inputs:**

- `.claude/state/component-registry.json` — REQUIRED. Missing → stop with "No registry. Run `/docs-creator:create-frontend-docs` or `/docs-creator:analyze-frontend` first."
- `--fix` flag if passed

### Step 1 — Load + parse

Parse JSON. If parse error → emit:

```text
[FATAL] component-registry.json is malformed at line <N>: <reason>
        Recover from git history or recreate via /docs-creator:analyze-frontend.
```

Stop. Do NOT auto-rewrite.

If parse OK, build:

- `byName: Map<name, entry>`
- `byPath: Map<path, entry[]>` (path → list, since collisions are possible)

### Step 2 — Disk existence check

For each entry, check `path` exists on disk (relative to project root).

| Result | Finding | Severity |
| ---- | ---- | ---- |
| File exists | `OK_DISK` | — |
| File missing AND `status` already `"stale"` | `STALE_CONFIRMED` | info |
| File missing AND `status` IS NOT `"stale"` | `MISSING_FILE` | warn (fixable) |
| `path` empty or null AND `status: "scanned-only"` | `OK_DISK` (scanner couldn't resolve yet) | — |
| `path` empty or null AND `status` ∈ {managed, pending, done} | `MISSING_PATH` | error |

### Step 3 — Dependency graph check (`uses[]`)

For each entry's `uses[]` array, verify each dep name resolves to an entry in `byName`:

| Result | Finding | Severity |
| ---- | ---- | ---- |
| Dep name found in registry | `OK_DEP` | — |
| Dep name NOT in registry | `BROKEN_DEP` (entry `<name>` uses unknown `<dep>`) | warn |
| Dep is `type: "local"` AND parent name doesn't match | `LOCAL_LEAK` (local component referenced outside its parent's tree) | warn |
| Same `name` appears in `uses[]` of ≥2 distinct entries AND `type: "local"` | `PROMOTION_CANDIDATE` (`<name>` reused — consider promoting to `feature` or `primitive`) | info |

### Step 4 — Schema + collision audit

**Schema (per `rules/registry-schema.md`):**

For each entry, validate keys against the allowed-fields list:

```text
Allowed: name, type, layer, path, figma_node_id, figma_file_key, figma_connected,
         uses, parent, variants, states, created_at, last_verified_at,
         last_figma_sync_at, figma_last_modified, ssim_score, status,
         description, last_scanned_at
```

(`description` + `last_scanned_at` added in M13 1.4 — also allowed.)

| Result | Finding | Severity |
| ---- | ---- | ---- |
| All keys allowed | `OK_SCHEMA` | — |
| Forbidden key present (e.g. `notes`, `sec_icon_ssim`, `figma_url`) | `SCHEMA_VIOLATION` (entry `<name>`: forbidden key `<k>`) | error (NOT auto-fixed — user must move data to memory or discard) |
| Required key missing (`name`, `type`, `path`, `status`) | `SCHEMA_MISSING_REQUIRED` | error |
| `status` value not in enum `{scanned-only, managed, pending, done, stale, in-progress, needs-review, unverified}` | `SCHEMA_BAD_STATUS` | error |
| `type` value not in `{primitive, feature, local}` | `SCHEMA_BAD_TYPE` | error |

**Name collisions:**

| Result | Finding | Severity |
| ---- | ---- | ---- |
| `byName.get(name).length == 1` | `OK_NAME` | — |
| Same `name` ∈ ≥2 entries (different paths) | `NAME_COLLISION` (`<name>` exists at: `<path1>`, `<path2>`) | error |

**Path collisions:**

| Result | Finding | Severity |
| ---- | ---- | ---- |
| `byPath.get(path).length == 1` | `OK_PATH` | — |
| Same `path` ∈ ≥2 entries (different names) | `PATH_COLLISION` (`<path>` claimed by: `<name1>`, `<name2>`) | error |

**M13 staleness signal (scanned-only entries that have lingered):**

| Result | Finding | Severity |
| ---- | ---- | ---- |
| `status: "scanned-only"` AND `last_scanned_at` > 30d ago | `SCANNED_ONLY_STALE` (`<name>` discovered >30 days ago, never promoted to managed) | info |

### Step 5 — Apply --fix (skip if not passed)

Safe auto-fixes only. Anything requiring human judgment is reported but NOT modified.

| Finding | Auto-fix |
| ---- | ---- |
| `MISSING_FILE` (status was not already stale) | Set `status: "stale"` on that entry |
| `STALE_CONFIRMED` | No change (already stale) |
| `NAME_COLLISION` | NOT auto-fixed (could lose user-intentional data) |
| `PATH_COLLISION` | NOT auto-fixed |
| `SCHEMA_VIOLATION` | NOT auto-fixed (data goes to memory, not silently dropped) |
| `SCHEMA_MISSING_REQUIRED` | NOT auto-fixed |
| `BROKEN_DEP` | NOT auto-fixed (could be a typo or rename in flight) |
| `PROMOTION_CANDIDATE` | NOT auto-fixed (architectural decision) |
| `SCANNED_ONLY_STALE` | NOT auto-fixed (informational only) |

If any fix was applied:

- Update `generated.ts = now()`
- Atomic write (temp + rename)
- Report each fix with `[FIX]` prefix

### Step 6 — Report

Save to `.claude/state/reports/validate-registry-<DISPLAY_TS>.md`. Body summary:

```text
╭─ Validate Registry ─────────────────────────────────────────╮
│  N total entries audited                                    │
│                                                             │
│  Disk:        K ok   ·   P missing   ·   Q stale            │
│  Deps:        K ok   ·   L broken    ·   M promotion-cands  │
│  Schema:      K ok   ·   V violations ·  Z missing-required │
│  Collisions:  C name  ·  D path                             │
│                                                             │
│  --fix applied: F changes                                   │
╰─────────────────────────────────────────────────────────────╯
```

Per-finding detail in sections below the box. Top-level severity tally at the very top:

- `[ERR] <n>` — total errors (schema, collisions, missing path)
- `[WARN] <n>` — total warnings (missing files, broken deps, local leaks)
- `[INFO] <n>` — promotion candidates, stale-confirmed, scanned-only-stale

Exit-style codes (logged but not actual shell exits):

| Code | Meaning |
| ---- | ---- |
| 0 | Clean (no errors, no warnings) |
| 1 | Warnings only |
| 2 | At least one error |

### Conditional behaviors

- Empty registry (`components: []`) → stop with "Registry has no components yet. Use `/component-creator:create-component <name>` or `/docs-creator:analyze-frontend` to populate."
- Registry file present but no `components` key → `[FATAL]` schema, stop, no auto-rewrite.
- `--fix` passed but registry has any `error`-severity findings other than `MISSING_FILE` → still apply the safe MISSING_FILE fixes, but emit `[BLOCKED] errors prevent further automation — resolve manually` at the end.

## What this skill does NOT do

- Does NOT delete entries (use `/remove-component` for intentional removal)
- Does NOT modify `uses[]`, `path`, `name`, `type` automatically (those are user-intent)
- Does NOT contact Figma (`/sync-registry` does)
- Does NOT run SSIM verification (`/update-component --verify` does)
- Does NOT rewrite the registry's `schema_version` (use migration flags on `/docs-creator:update-frontend-docs`)
- Does NOT enforce naming conventions beyond schema (PascalCase, BEM — those live in `frontend-components.md` rule)
