---
name: analyze-frontend
scope: api
description: "Analyze a project's frontend — detect frameworks, design system, components, data flow, architecture; generate scoped rules and docs into .claude/. Run after /init-project or standalone on any project with an existing .claude/."
user-invocable: true
argument-hint: "[frontend-path] [--only <area>]"
---

# Analyze Frontend

> **Flow:** read all files in `sequences/analyze-frontend/` — the sequence diagrams are the source of truth for execution order:
> — `analyze-frontend.mmd` — end-to-end sequence (user → detection → waves → assembly → report)
> — `two-wave-fanout.mmd` — why Wave 2 depends on Wave 1's stack_profile; when each subagent fires
> — `template-assembly.mmd` — which subagent output feeds which section of the primary template
> — `framework-classification.mmd` — pattern-first decision tree inside framework-idiom-extractor (industry / custom / vanilla)
>
> Primary-output format: `rules/component-creation-template-format.md` — spec for `reference-component-creation-template.md`
> Subagent specs: `agents/frontend-detector.md`, `agents/tech-stack-profiler.md`, `agents/design-system-scanner.md`, `agents/component-inventory.md`, `agents/data-flow-mapper.md`, `agents/architecture-analyzer.md`, `agents/framework-idiom-extractor.md`, `agents/feature-flow-detector.md`
> Fan-out pattern: `docs/reference-subagent-fanout-pattern.md` — decision heuristic, return-shape contract
> Reference: read `docs/how-to-create-docs.md`
> Style rules: read `rules/markdown-style.md`, `rules/mermaid-style.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

**Read-only analyzer.** Detects frontend root(s), runs a two-wave subagent pipeline, and persists structured analysis to `.claude/state/frontend-analysis.json` (gitignored). **Writes NO user-facing documentation.**

To materialize the analysis as human-readable docs (`.claude/docs/reference-component-creation-template.md` + references + `CLAUDE.md` update), run `/create-frontend-docs` AFTER this skill. To refresh a specific area after code drift, run `/update-frontend-docs <area>`.

This split (analyze → create → update) mirrors the toolkit's existing `init-project` / `create-docs` / `update-docs` pattern.

Execution pattern: **two-wave fan-out** with stack-informed Wave 2.

- **Wave 1 — Stack profile**: `tech-stack-profiler` runs alone (serial gate), establishing `framework`, `rendering_mode`, `styling_model`, `class_naming`, `state_libs[]`, etc.
- **Wave 2 — Deep per-axis analysis (parallel)**: 5 specialists + `framework-idiom-extractor` run concurrently, each consuming Wave 1's `stack_profile` so their scans narrow (e.g., `design-system-scanner` skips `styled-components` lookups when stack says Tailwind).
- **Persist**: orchestrator serializes Wave 1 + Wave 2 outputs into a structured JSON and writes it to `.claude/state/frontend-analysis.json`.

Runs in two modes:

- **Auto-suggested** after `/init-project` when a frontend is detected (user accepts "run now?" checkpoint).
- **Standalone** on any project that already has a `.claude/` directory.

If `.claude/` is missing, the skill stops and directs the user to `/init-project`.

## What this skill creates

- `.claude/state/frontend-analysis.json` — **structured analysis result (gitignored)**. Machine-readable format readable by downstream component-creation agents directly, and consumed by `/create-frontend-docs` + `/update-frontend-docs`.
- `.claude/state/reports/analyze-frontend-<ts>.md` — run report per [rules/report-format.md](../../rules/report-format.md) (gitignored)

## What this skill does NOT create

- **No** `.claude/rules/frontend-*.md` (that is `/create-frontend-docs`)
- **No** `.claude/docs/reference-component-creation-template.md` (that is `/create-frontend-docs`)
- **No** `.claude/docs/reference-architecture-frontend.md` / `reference-component-inventory.md` (that is `/create-frontend-docs`)
- **No** `.claude/sequences/frontend-data-flow.mmd` (that is `/create-frontend-docs`)
- **No** edits to root `CLAUDE.md` (that is `/create-frontend-docs`)
- New modules, tests, CI configuration, custom rules — out of scope
- Anything outside `.claude/state/`

## Usage

```text
/analyze-frontend                            # auto-detect frontend roots in cwd
/analyze-frontend apps/web                   # analyze a specific sub-directory
/analyze-frontend --only design-system       # skip other specialists in Wave 2
/analyze-frontend apps/web --only components # combined
```

Filters accepted after `--only` (restrict Wave 2 specialists):

| Filter | Runs (in Wave 2) | JSON sections populated |
| ---- | ---- | ---- |
| `design-system` | design-system-scanner | `design_system` |
| `components` | component-inventory | `component_inventory` |
| `data-flow` | data-flow-mapper | `data_flow` |
| `architecture` | tech-stack-profiler + architecture-analyzer | `tech_stack` + `architecture` |
| `framework-idioms` | framework-idiom-extractor | `framework_idioms` |
| `feature-flows` | feature-flow-detector | `feature_flows` |
| `all` (default) | all 7 specialists | all sections |

Filtered runs write a PARTIAL JSON — unpopulated sections retain last-known values (if `.claude/state/frontend-analysis.json` exists) or are marked `null`.

## Interactive Wizard

The skill runs as a guided wizard with user checkpoints — not a silent batch.

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Orientation | Detected frontend(s) + existing analysis age + artefacts on disk with ages | Full rerun / `--only <area>` / skip (data is fresh)? |
| Deep analysis complete | Per-frontend summary (stack, token count, component count, data-flow style) | Confirm persist to JSON? (Default yes) |
| Report | Dashboard + path to analysis JSON + suggestion to run `/create-frontend-docs` | — |

## Composition

This skill is a **two-wave fan-out pipeline** producing a structured JSON result — one detection subagent (gating) + one stack-profile subagent (Wave 1) + six specialist subagents (Wave 2) + orchestrator-side JSON serialization.

| Phase | Owner | Responsibility |
| ---- | ---- | ---- |
| Preflight | **this skill** | Confirm `.claude/` exists; capture `START_TS` |
| Detect frontends | `frontend-detector` subagent | Enumerate frontend roots — cheap glob, no user interaction |
| **Orientation** | **this skill** | Single user checkpoint: show detected frontends + existing analysis age + artefacts on disk with ages; ask full rerun / `--only <area>` / skip |
| **Wave 1 — Stack profile** | `tech-stack-profiler` subagent (per frontend) | Return full `stack_profile`: framework, rendering mode, `styling_model`, `class_naming`, state libs, bundler, etc. Wave 2 depends on this. |
| **Wave 2 — Deep analysis (parallel)** | 7 specialists (per frontend, concurrent): `framework-idiom-extractor`, `design-system-scanner`, `component-inventory`, `data-flow-mapper`, `architecture-analyzer`, `feature-flow-detector` | Each consumes Wave 1's `stack_profile` for narrower scans. Returns `{summary_row, artefact_body}` or `SKIP` |
| **Persist analysis** | **this skill** | Merge Wave 1 + Wave 2 results into structured JSON; write to `.claude/state/frontend-analysis.json`. If file exists and `--only` filter was used, preserve sections not in the filter (merge, don't overwrite) |
| Report | **this skill** | Persist run report per `rules/report-format.md`; dashboard on-screen points at JSON and suggests `/create-frontend-docs` |

**Why this skill is read-only:** Separating analysis from writing is what enables `/create-frontend-docs` and `/update-frontend-docs` to exist as distinct composable skills. It also makes the JSON directly consumable by downstream component-creation agents who want programmatic access without a parse-MD step.

**Why two waves, not one parallel fan-out:** Wave 2 specialists benefit significantly from knowing the stack. `design-system-scanner` skips `styled-components` lookup when Wave 1 says Tailwind. `component-inventory` globs `.vue` files vs `.tsx` based on framework. `framework-idiom-extractor` selects framework-specific deep-dive branch from `framework_classification`. Running everything in one parallel wave wastes Wave-2 scans on wrong file patterns.

## Reference

The sequence diagram defines order. Sections below describe only the phases with non-trivial logic.

### Phase: Preflight

Capture the start timestamp at the very first step:

```bash
Bash: START_TS=$(date +%s); RUN_TS=$(date -u +%Y%m%dT%H%M%SZ); DISPLAY_TS=$(date +%Y%m%d-%H%M%S); echo "START_TS=$START_TS RUN_TS=$RUN_TS DISPLAY_TS=$DISPLAY_TS"
```

Preserve these values through the run. Per-phase timestamps are optional but preferred (feed the Phase Timings table in the report).

Check `.claude/` directory exists in cwd. If absent, stop and point to `/init-project`. Do NOT scaffold it here — that is `/init-project`'s job.

### Phase: Detect frontends (delegated)

Invoke the `frontend-detector` subagent (see [agents/frontend-detector.md](../../agents/frontend-detector.md) for the full contract) with:

| Field | Value |
| ---- | ---- |
| `project_root` | Absolute cwd |
| `user_hint_path` | The `[frontend-path]` argument if given, else empty |

It returns a flat list: `[{path, framework, entry_points, confidence}]`. Zero results → stop with a "No frontend roots found" message.

### Phase: Orientation (single user checkpoint)

After detection completes, read existing state and present everything in one box:

1. Read `.claude/state/frontend-analysis.json` if present — extract `schema_version`, `generated.ts`, `generated.plugin_version`, `generated.frontends_analyzed`, `generated.only_filter`.
2. Glob artefacts + get age via `git log -1 --format="%cr" -- <file>` (fallback `stat` if untracked):
   - `.claude/docs/reference-component-creation-template*.md`
   - `.claude/rules/frontend-design-system*.md` + `frontend-components*.md`
   - `.claude/docs/reference-architecture-frontend*.md` + `reference-component-inventory*.md`
   - `.claude/sequences/frontend-data-flow*.mmd` + `features/*.mmd`
3. Show one combined box followed by a numbered select menu:

```text
  ┌─ analyze-frontend ────────────────────────────────────────┐
  │                                                           │
  │  Detected frontends:                                      │
  │    1. apps/web        (Next.js)   ← main                  │
  │    2. apps/marketing  (Astro)                             │
  │                                                           │
  │  Existing analysis: 5 days ago · plugin v0.14.0           │
  │    last filter: all · 2 frontends                         │
  │                                                           │
  │  Artefacts on disk:                                       │
  │    reference-component-creation-template.md   5d ✓        │
  │    frontend-design-system.md                  5d ✓        │
  │    frontend-components.md                     5d ✓        │
  │    reference-architecture-frontend.md         5d ✓        │
  │    reference-component-inventory.md           5d ✓        │
  │    frontend-data-flow.mmd                    32d ✗        │
  │    sequences/features/ (2 files, oldest 5d)   5d ✓        │
  │                                                           │
  └───────────────────────────────────────────────────────────┘

  What to do?
    [1] Full analysis — all frontends, all areas        (default)
    [2] Full analysis — only apps/web (main)
    [3] Refresh stale area — --only data-flow            (⚠ 1 stale)
    [4] Choose custom --only <area> or subset of roots
    [5] Skip — data is mostly fresh, go to /create-frontend-docs

  Reply with a number or type a custom filter (e.g. "1,3" / "--only components"):
```

When no prior state exists: omit the artefacts block and options [3]/[5], show only [1] (full) and [4] (custom).

When no stale artefacts: omit option [3].

4. Parse reply:
   - number → map to action above
   - `--only <area>` text → run matching specialists, merge JSON
   - free-form root selection (`"1,2"`) → limit detection scope and run full wave on those roots

Age thresholds: fresh < 7 days `✓`, aging 7–30 days `⚠`, stale > 30 days `✗`.

### Phase: Wave 1 — Stack profile (per frontend)

For each confirmed frontend root, invoke `tech-stack-profiler` SERIALLY before Wave 2 starts. If there are multiple frontends, they can run in parallel with each other (but each independently before its own Wave 2).

Invocation prompt includes:

| Field | Value |
| ---- | ---- |
| `frontend_root` | Absolute path to the frontend directory |
| `project_root` | Absolute cwd |
| `framework_hint` | Framework name from `frontend-detector` output |
| `entry_points` | List of entry-point file paths from `frontend-detector` |
| `style_rules_path` | Relative path to `rules/markdown-style.md` in the loaded plugin |

Wait for the return before starting Wave 2. Preserve the full `stack_profile` return:

- `framework`, `framework_version`, `rendering_mode`
- `language`, `ts_strictness`
- `bundler`, `package_manager`
- **`styling_model`** and **`class_naming`** — these are critical for the primary template's Styling/Classes sections (see `agents/tech-stack-profiler.md` for the enum values)
- `state_management[]`, `routing`, `data_fetching[]`, `ui_library[]`, `testing[]`, `linting[]`

### Phase: Wave 2 — Deep analysis (parallel, stack-informed)

Once Wave 1 has returned for ALL confirmed frontend roots, fire Wave 2: **7 specialists × N frontends invocations in a single message** (concurrent).

Specialists in Wave 2:

1. `framework-idiom-extractor` — pattern-first framework classification (industry / custom / vanilla); idiomatic rules for new components
2. `design-system-scanner` — tokens, theme config, dark-mode strategy
3. `component-inventory` — existing components tree + conventions + canonical skeleton pick
4. `data-flow-mapper` — state + API + auth + forms; emits one top-level Mermaid data-flow diagram
5. `architecture-analyzer` — folder layout, routing, SSR boundaries
6. `feature-flow-detector` — identifies individual user-facing features and classifies each by data flow pattern (scan-loop / query-display / settings-rw / action-executor / orchestrator / dashboard); emits per-pattern Mermaid fragments and a feature registry for `.claude/sequences/features/`

If `--only <area>` was specified, invoke only the matching specialists.

Each Wave 2 invocation prompt MUST include:

| Field | Value |
| ---- | ---- |
| `frontend_root` | Absolute path to the frontend directory |
| `project_root` | Absolute cwd |
| `stack_profile` | **The full Wave 1 return** — specialists consume this to narrow scans |
| `entry_points` | Entry-point file paths |
| `style_rules_path` | Relative path to `rules/markdown-style.md` in the loaded plugin |
| `target_file_shape` | Brief reminder of the expected return format |

**Fan-in contract** — every specialist returns two sections:

1. `## Summary Row` — a YAML block specific to that specialist (see each subagent spec for fields).
2. `## <Artefact>` — the full markdown content for the artefact this specialist writes or contributes (or the sentinel literal `SKIP` if nothing applies — e.g., a static Astro site has no data-flow; `framework-idiom-extractor` returns SKIP for `vanilla`).

Orchestrator parses by heading. Failures are logged to the run report's `Notes`, not escalated to abort.

### Phase: Persist structured analysis

After Wave 2 returns for all frontends, the orchestrator serializes the combined Wave 1 + Wave 2 outputs into a structured JSON and writes it to `.claude/state/frontend-analysis.json` in the target project. This file is gitignored (`.claude/state/` is in the toolkit's standard gitignore block).

JSON schema:

```json
{
  "schema_version": "1.1",
  "generated": {
    "plugin_version": "<e.g. 0.13.0>",
    "skill": "analyze-frontend",
    "ts": "<ISO-8601 UTC>",
    "wall_clock_sec": <int>,
    "frontends_analyzed": <int>,
    "only_filter": "<null | design-system | components | data-flow | architecture | framework-idioms | all>"
  },
  "frontend_roots": [
    {
      "path": "<absolute>",
      "relative": "<project-relative>",
      "detector": {
        "framework": "<from frontend-detector>",
        "framework_version": "<major.minor>",
        "entry_points": [...],
        "confidence": "high|medium|low",
        "package_manager": "pnpm|yarn|npm|bun"
      },
      "tech_stack": { /* full stack_profile from Wave 1 */ },
      "framework_idioms": { /* framework-idiom-extractor Summary Row + body */ },
      "design_system": { /* design-system-scanner Summary Row + body */ },
      "component_inventory": { /* component-inventory Summary Row + body + canonical_skeleton_excerpt */ },
      "data_flow": { /* data-flow-mapper Summary Row + Mermaid diagram string */ },
      "architecture": { /* architecture-analyzer Summary Row + body */ },
      "feature_flows": { /* feature-flow-detector Summary Row + per-pattern Mermaid fragments */ }
    }
  ]
}
```

Each subagent's `## Summary Row` YAML block is parsed into the corresponding JSON object; the `## <Artefact>` markdown body is stored as a string in a `body_markdown` field so `/create-frontend-docs` can emit it to disk without regeneration.

**Merge behavior** — if `.claude/state/frontend-analysis.json` already exists:

- If this run has no `--only` filter (default, full run) → **overwrite** the entire file.
- If `--only <area>` was passed → **merge**: preserve sections of `frontend_roots[*]` that were NOT in the filter, replace only the filtered sections. Update `generated.ts` and `generated.only_filter` accordingly.

This enables incremental refresh without losing unrelated analysis data.

### Phase: Report

Write the run report to `.claude/state/reports/analyze-frontend-<DISPLAY_TS>.md`.

**REQUIRED — exact first-line format** (not negotiable, do NOT use JSON, do NOT rename keys):

```text
<!-- report: skill=analyze-frontend ts=<ISO-UTC> wall_clock_sec=<int> frontends=<N> artefacts=<int> stack=<aggregated-per-root> -->
```

Hard rules:

- **Prefix is literal `<!-- report: `** — NOT `<!-- meta: `, not `<!-- run: `.
- **Format is `key=value` pairs separated by spaces** — NOT a JSON object.
- **Key names exactly** — `ts` (NOT `run_ts`), `wall_clock_sec`, `frontends` (M8-specific alias of `modules`; use `frontends` here because units being counted are frontend roots, not modules), `artefacts` (NOT `artefact_count`), `stack` (e.g. `next.js+tailwind,vite+react`).
- Single line; no quoted values unless the value contains spaces.

**Per-phase timings are REQUIRED**, captured at each phase boundary:

```bash
Bash: PHASE_<NAME>_START=$(date +%s)
Bash: PHASE_<NAME>_END=$(date +%s); PHASE_<NAME>_SEC=$((PHASE_<NAME>_END - PHASE_<NAME>_START))
```

Phases to time: `PREFLIGHT`, `DETECT`, `ORIENTATION`, `WAVE_1_STACK`, `WAVE_2_ANALYSIS` (the parallel fan-out), `PERSIST_JSON`, `REPORT`. Missing timings go to `## Notes` as `timing_missing=<phase>`, never estimated.

See [rules/report-format.md](../../rules/report-format.md) as source of truth.

Body sections:

- `## Summary` — frontends analyzed, stacks found, duration, analysis JSON path
- `## Phase Timings` — per-phase durations
- `## Per-frontend findings` — per-root table: stack profile, design-system characterization, component count, data-flow style, framework classification
- `## Artefacts` — just the JSON file and the report (this skill writes no other artefacts)
- `## Next-step Recommendations` — always suggest `/create-frontend-docs` (to materialize the analysis as human-readable docs) and mention `/update-frontend-docs <area>` for targeted refreshes later
- `## Notes` (optional) — subagent failures, surprises, cleanup candidates

End-of-run dashboard on screen: frontends, stacks, duration, `JSON ✓ .claude/state/frontend-analysis.json`, `Report ✓ .claude/state/reports/analyze-frontend-<ts>.md`, and a prominent "**Next: run `/create-frontend-docs` to materialize docs**" call-to-action.

## Retrofit Behavior

When run on a project that already has a `.claude/state/frontend-analysis.json`:

- Full run (no `--only`) → overwrite JSON entirely
- Partial run (`--only <area>`) → merge JSON: preserve sections outside the filter, replace only filtered sections. Update `generated.ts` to reflect the latest partial run.

When run on a project that has `.claude/docs/reference-component-creation-template.md` or other frontend-* artefacts from a previous `/create-frontend-docs` run:

- This skill does NOT touch those files. It only writes the JSON. The user runs `/create-frontend-docs` separately to update the MDs.

## What This Skill Does NOT Do

- Scaffold `.claude/` — use `/init-project` first
- Analyze backend code — frontend-specific
- Write `.claude/docs/` or `.claude/rules/` artefacts — that's `/create-frontend-docs`
- Update root `CLAUDE.md` Architecture section — that's `/create-frontend-docs`
- Configure linters, formatters, or CI — pure read + describe
- Invent patterns not observed in the code — subagents surface only what they find, same discipline as `module-documenter`
