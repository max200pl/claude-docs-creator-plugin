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
> Phase reference: read `docs/reference-analyze-frontend-detection.md`
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

Phase-by-phase implementation details: [`docs/reference-analyze-frontend-detection.md`](../../docs/reference-analyze-frontend-detection.md)

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
