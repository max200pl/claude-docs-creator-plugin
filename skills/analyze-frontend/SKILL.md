---
name: analyze-frontend
scope: api
description: "Analyze a project's frontend — detect frameworks, design system, components, data flow, architecture; generate scoped rules and docs into .claude/. Run after /init-project or standalone on any project with an existing .claude/."
user-invocable: true
argument-hint: "[frontend-path] [--only <area>]"
---

# Analyze Frontend

> **Flow:** read all files in `sequences/analyze-frontend/` — the sequence diagram is the source of truth for execution order
> Subagent specs: `agents/frontend-detector.md`, `agents/tech-stack-profiler.md`, `agents/design-system-scanner.md`, `agents/component-inventory.md`, `agents/data-flow-mapper.md`, `agents/architecture-analyzer.md`
> Fan-out pattern: `.claude/docs/subagent-fanout-pattern.md` — decision heuristic, return-shape contract
> Reference: read `docs/how-to-create-docs.md`
> Style rules: read `rules/markdown-style.md`
> Output rules: read `rules/output-format.md`
> Report rules: read `rules/report-format.md`

Orchestrator. Detects frontend root(s) in the project, confirms with the user, fans out to five specialist subagents per frontend in parallel, collects their outputs, and writes scoped `.claude/` artefacts. Updates the root `CLAUDE.md` Architecture section with `@` imports for the new files.

Runs in two modes:

- **Auto-suggested** after `/init-project` when a frontend is detected (user accepts "run now?" checkpoint).
- **Standalone** on any project that already has a `.claude/` directory — retrofit or refresh.

If `.claude/` is missing, the skill stops and directs the user to `/init-project`.

## What this skill creates

Artefacts land in the target project's `.claude/` — never in the plugin. Filenames use a root-specific suffix when multiple frontends are detected, plain names otherwise.

- `.claude/rules/frontend-design-system.md` — design tokens, CSS variables, theme configuration, with `paths:` scoped to theme/token files
- `.claude/rules/frontend-components.md` — component conventions (naming, prop shapes, class structure), with `paths:` scoped to components folders
- `.claude/docs/architecture-frontend.md` — architecture overview + rendering mode (SSR/SPA/SSG) + folder-boundary map
- `.claude/docs/component-inventory.md` — table of notable components with purpose and location
- `.claude/sequences/frontend-data-flow.mmd` — state + API data-flow diagram
- `.claude/state/reports/analyze-frontend-<ts>.md` — run report per [rules/report-format.md](../../rules/report-format.md) (gitignored)
- `CLAUDE.md` — Architecture section updated with `@` imports to the above (surgical edit; other sections untouched)

## What this skill does NOT create

- New modules under `projects/` or `src/` — it only describes what exists
- Tests or CI configuration
- Project-specific skills or custom rules beyond the ones listed above
- Any artefact outside the target project's `.claude/` or root `CLAUDE.md`

## Usage

```text
/analyze-frontend                            # auto-detect frontend roots in cwd
/analyze-frontend apps/web                   # analyze a specific sub-directory
/analyze-frontend --only design-system       # skip components/data-flow/architecture
/analyze-frontend apps/web --only components # combined
```

Filters accepted after `--only`:

| Filter | Runs | Writes |
| ---- | ---- | ---- |
| `design-system` | design-system-scanner | `frontend-design-system.md` |
| `components` | component-inventory | `frontend-components.md` + `component-inventory.md` |
| `data-flow` | data-flow-mapper | `frontend-data-flow.mmd` |
| `architecture` | tech-stack-profiler + architecture-analyzer | `architecture-frontend.md` |
| `all` (default) | all 5 specialists | everything |

## Interactive Wizard

The skill runs as a guided wizard with user checkpoints — not a silent batch.

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Detect frontends | List of detected roots with framework + entry point | Correct? Add/remove any? Specific area to focus on? |
| Deep analysis complete | Per-frontend summary table (stack, token count, component count, data-flow style) | Write all artefacts? Any to skip? |
| Report | Dashboard + `@` imports added to CLAUDE.md | Anything to regenerate? |

## Composition

This skill is a pipeline: one detection subagent + five specialist subagents (fan-out) + orchestrator-side aggregation and writes.

| Phase | Owner | Responsibility |
| ---- | ---- | ---- |
| Preflight | **this skill** | Confirm `.claude/` exists; capture `START_TS` |
| Detect frontends | `frontend-detector` subagent | Enumerate frontend roots; return list with framework + entry points |
| Confirm scope | **this skill** | User checkpoint — accept/modify root list |
| Deep analysis | 5 specialist subagents (parallel fan-out per frontend) | Each returns `{summary_row, artefact_body}` or `SKIP` for its area |
| Collect + write | **this skill** | Aggregate results; write artefacts; update root `CLAUDE.md` Architecture section surgically |
| Report | **this skill** | Persist run report per `rules/report-format.md` |

**Naming rule:** when N frontends > 1, artefact filenames gain a root-derived suffix (`frontend-design-system-web-app.md`). When N == 1, filenames stay plain (`frontend-design-system.md`).

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

### Phase: Confirm scope (interactive)

Show the list to the user. Accept: confirm as-is / remove specific entries / add a missed path. Also capture any `--only <area>` filter.

### Phase: Deep analysis (fan-out)

For each confirmed frontend root, invoke all five specialist subagents **in parallel** — i.e., fire all `N_frontends × 5` invocations in a single message. If `--only` was specified, only invoke matching specialists.

Each invocation prompt MUST include:

| Field | Value |
| ---- | ---- |
| `frontend_root` | Absolute path to the frontend directory |
| `project_root` | Absolute cwd — anchor for relative paths in output |
| `framework_hint` | Framework name from `frontend-detector` output |
| `entry_points` | List of entry-point file paths from `frontend-detector` |
| `style_rules_path` | Relative path to `rules/markdown-style.md` in the loaded plugin |
| `target_file_shape` | Brief reminder of the expected return format (see below) |

The subagent specs are source of truth for each specialist's scan depth and return content. SKILL.md does not duplicate them.

**Fan-in contract** — every specialist returns two sections:

1. `## Summary Row` — a YAML block specific to that specialist (see each subagent spec for fields).
2. `## <Artefact>` — the full markdown content for the artefact this specialist writes (or the sentinel literal `SKIP` if nothing applies — e.g., a static Astro site has no data-flow).

Orchestrator parses by heading. Failures are logged to the run report's `Notes`, not escalated to abort.

### Phase: Collect and write artefacts

Aggregate per-frontend results. File naming:

- If `frontend_roots.length == 1` → plain filenames (`frontend-design-system.md`, `architecture-frontend.md`, `component-inventory.md`, `frontend-components.md`, `frontend-data-flow.mmd`)
- If `frontend_roots.length > 1` → suffix with a slug derived from the root's basename (`frontend-design-system-web-app.md`, etc.)

Skip writing any artefact whose specialist returned `SKIP`. Every skipped artefact is still noted in the run report.

**Paths-scoping for generated rules** — two rule files get `paths:` frontmatter so they auto-load only when Claude edits matching files:

- `frontend-design-system.md` → `paths: ["<frontend_root>/**/*.{css,scss,sass}", "<frontend_root>/*tailwind*.{js,ts,cjs}", "<frontend_root>/**/*token*", "<frontend_root>/**/theme*.*"]`
- `frontend-components.md` → `paths: ["<frontend_root>/src/components/**", "<frontend_root>/components/**", "<frontend_root>/src/ui/**"]`

The subagents produce the markdown body; the orchestrator prepends the frontmatter block based on detected paths.

### Phase: Update root CLAUDE.md Architecture section

Surgical edit — read CLAUDE.md, locate the `## Architecture` heading, append `@`-style import references for each newly-created file at the end of that section. Do NOT touch other sections (Build & Run, Project Structure, Code Conventions, Git Conventions, etc.).

Example addendum (inserted before next `##` heading):

```markdown
### Frontend

- See [.claude/docs/architecture-frontend.md](.claude/docs/architecture-frontend.md) for the frontend architecture overview.
- Design system tokens: `@.claude/rules/frontend-design-system.md`
- Component conventions: `@.claude/rules/frontend-components.md`
- Data flow diagram: `.claude/sequences/frontend-data-flow.mmd`
```

If the Architecture section already contains a `### Frontend` subsection (from a previous run), replace it in place — do not duplicate.

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

Phases to time: `PREFLIGHT`, `DETECT`, `CONFIRM`, `DEEP_ANALYSIS` (the parallel fan-out), `WRITE`, `UPDATE_CLAUDE_MD`, `REPORT`. Missing timings go to `## Notes` as `timing_missing=<phase>`, never estimated.

See [rules/report-format.md](../../rules/report-format.md) as source of truth.

Body sections:

- `## Summary` — frontends analyzed, stacks found, duration, artefacts written
- `## Phase Timings` — Preflight, Detect, Confirm, Deep analysis, Write, Report
- `## Per-frontend findings` — per-root table: stack profile, design-system characterization, component count, data-flow style, architecture mode
- `## Artefacts` — path / lines / category
- `## Next-step Recommendations` — optional follow-up skills (`/create-docs rule` for project-specific patterns, `/create-mermaid` for additional flows, `/update-docs --refresh frontend:<area>` once code drifts)
- `## Notes` (optional) — subagent failures, surprises, cleanup candidates

End-of-run dashboard on screen: frontends, stacks, duration, `Report ✓ .claude/state/reports/analyze-frontend-<ts>.md`.

## Retrofit Behavior

When run on a project whose `/init-project` did NOT detect frontends (pre-M8 run, or frontend added later):

- Adds all new artefacts without touching existing module `CLAUDE.md` files
- Updates root `CLAUDE.md` only in the Architecture section
- Does not re-run stack detection at project level — uses `frontend-detector` which is narrower

When run on a project that already has previous-run artefacts (re-run scenario):

- Overwrites `.claude/rules/frontend-*.md` and `.claude/docs/*frontend*.md` with fresh content
- Preserves any hand-edits? No — rewrites from scratch. Users who want to preserve overrides should instead use `/update-docs --refresh frontend:<area>` once it lands.

## What This Skill Does NOT Do

- Scaffold `.claude/` — use `/init-project` first
- Analyze backend code — this is frontend-specific
- Create per-component `CLAUDE.md` files — only the aggregate inventory in `.claude/docs/component-inventory.md`
- Configure linters, formatters, or CI — pure read + describe
- Invent patterns not observed in the code — subagents must surface only what they find, same discipline as `module-documenter`
