---
name: sync-registry
description: "Refresh Figma Code Connect state for all components in the registry. Calls Figma's get_code_connect_map for each primitive, updates figma_connected status, flags stale figma_node_id references. M13-aware: skips 'scanned-only' entries (not yet managed by component-creator). Use periodically or after Figma file restructuring."
scope: api
argument-hint: "[--dry-run]"
allowed-tools: [Read, Write, Edit, Bash, mcp__figma__get_code_connect_map, mcp__figma__get_design_context]
---

# Sync Registry

> **Registry schema:** `rules/registry-schema.md` (canonical) + `plugins/docs-creator/docs/reference-frontend-analysis-schema.md` § Component Registry Schema (M13 1.4)

Refresh `figma_connected` + `last_figma_sync_at` + `figma_last_modified` fields in `component-registry.json` by querying Figma Code Connect API for each managed entry. Detects components that LOST their Figma mapping (file restructuring, node deletion) and flags them.

## Usage

```text
/component-creator:sync-registry              # full sync — all managed entries
/component-creator:sync-registry --dry-run    # show what would change without writing
```

## When to use

- After Figma file restructuring (nodes moved/renamed/deleted) — verifies registry mappings still resolve
- Before a release — confirms all primitives have working Code Connect
- Periodically (weekly/monthly) — catches drift between code + Figma

NOT for adding new components (use `/create-component`) or editing entries (use `/update-registry`).

## Execution

### ⚙ Version check — OUTPUT BANNER FIRST per UserPromptSubmit hook

### Step 0 — Preflight (MANDATORY)

**0.1 TodoWrite** — call FIRST:

```text
☐ 0  Preflight
☐ 1  Load registry
☐ 2  Figma auth check (whoami)
☐ 3  Per-entry Code Connect query (in batches)
☐ 4  Compute diffs
☐ 5  Write registry (skip if --dry-run)
☐ 6  Report
```

**0.2 Read inputs:**

- `.claude/state/component-registry.json` — REQUIRED; if missing → stop with "No registry. Run /docs-creator:create-frontend-docs or /docs-creator:analyze-frontend first."
- Confirm schema_version field if present (M13: registry has its own schema_version, currently "1.0")
- `--dry-run` flag if passed

**0.3 Figma auth check:**

`mcp__figma__whoami()` — on 401, stop with: "Figma auth failed. Sign in via Figma desktop app, then retry."

### Step 1 — Load + filter registry

Read `.claude/state/component-registry.json`. Categorize entries by `status`:

| Status | Action |
| ---- | ---- |
| `"scanned-only"` (M13) | **SKIP** — not managed by component-creator yet; no Figma mapping expected |
| `"managed"`, `"pending"`, `"done"` | **PROCESS** — must have valid `figma_file_key` + `figma_node_id` to sync |
| `"stale"` (M13) | **SKIP** — file gone on disk; report-only |

Build worklist: entries with status in {managed, pending, done} AND `figma_node_id != null`.

Empty worklist → emit "No managed entries with Figma mappings to sync" and stop.

### Step 2 — Per-entry Code Connect query (batched)

For each entry in worklist, in batches of ~10 parallel calls:

```text
mcp__figma__get_code_connect_map(file_key=<entry.figma_file_key>)
```

The map returns Code Connect mappings for the entire file. For each entry compare against returned map:

| Detected state | Update entry |
| ---- | ---- |
| `entry.figma_node_id` IS in returned map AND points to entry's `path` | `figma_connected: true`, `last_figma_sync_at: now()`. If map has `last_modified` → also update `figma_last_modified`. |
| `entry.figma_node_id` IS in map BUT points to different path | `figma_connected: false`, append note to registry's top-level `sync_warnings[]`: `"<name> mapped to different path: <expected> vs <actual>"`. Do NOT auto-fix path. |
| `entry.figma_node_id` IS NOT in map (deleted/moved in Figma) | `figma_connected: false`, append warning: `"<name> node_id <id> no longer in Figma file"`. Do NOT clear `figma_node_id` automatically. |
| Figma file unreachable (404, permission) | Skip entry; append to `sync_warnings[]`: `"<name>: Figma file <key> unreachable"`. Preserve previous state. |

### Step 3 — Compute diffs

Snapshot before state vs after state per entry. Categorize:

- `connected` → still connected (no change)
- `newly_connected` → was false, now true
- `newly_disconnected` → was true, now false
- `unreachable` → couldn't query
- `unchanged_disconnected` → false before, false after

### Step 4 — Write registry (skip if `--dry-run`)

If `--dry-run`: print full diff table, DO NOT write.

Otherwise:

- Update `components[]` entries with new fields
- Update top-level `generated.ts = now()`
- Append `sync_warnings[]` if any (replace previous warnings list)
- Update `generated.last_sync_ts = now()` (M13 — new field; orchestrator may need to add it)
- Atomic write (temp + rename)

### Step 5 — Report

Per `rules/report-format.md`. Save to `.claude/state/reports/sync-registry-<DISPLAY_TS>.md`.

Body summary:

```text
╭─ Sync Registry ─────────────────────────────────────────────╮
│  N total managed entries scanned                            │
│  M Code Connect mappings verified                            │
│                                                             │
│  ✓ K still connected                                        │
│  + L newly connected (previously disconnected, now mapped)  │
│  − P newly disconnected (lost Figma mapping)                │
│  ? Q unreachable (skipped)                                  │
│                                                             │
│  N skipped (status: scanned-only)                           │
│  Z skipped (status: stale — file gone)                      │
╰─────────────────────────────────────────────────────────────╯
```

If any `newly_disconnected` — list them with action recommendation (re-link via Figma, OR delete via `/remove-component`).

### Conditional behaviors

- All entries in registry are `scanned-only` (fresh project) → stop with: "Registry has no managed components yet. Use `/component-creator:create-component <name>` to start managing a component."
- Figma API rate limit hit → batch in smaller groups (5 at a time); retry once on 429; otherwise warn and partial-write what completed.
- Registry file locked by another process → stop with retry hint.

## What this skill does NOT do

- Does NOT modify `figma_node_id` automatically (preserves user-intentional mapping; only flags drift)
- Does NOT delete entries (use `/remove-component`)
- Does NOT add scanned-only entries to managed status (that's `/create-component`'s job)
- Does NOT verify SSIM (use `/update-component` for visual re-verification)
- Does NOT touch frontend-analysis.json (it's a different artefact, refreshed via `/update-frontend-docs`)
