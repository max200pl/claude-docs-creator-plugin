# /init-project — Phase Reference

> Consumed by `skills/init-project/SKILL.md`. Detailed implementation instructions for each phase in the [sequence diagrams](../sequences/init-project/).

## Scaffold .claude structure

Create the full `.claude/` tree and root-level files in one pass:

```text
<project-root>/
  CLAUDE.md                       ← project overview (filled in Create CLAUDE.md phase)
  CLAUDE.local.md                 ← personal overrides (gitignored, empty)
  .claude/
    settings.json                 ← permissions, hooks (empty default: {})
    settings.local.json           ← personal settings (gitignored, empty default: {})
    rules/                        ← path-scoped rules
    docs/                         ← project documentation
    skills/                       ← project-specific skills
    sequences/                    ← Mermaid sequence diagrams
    agents/                       ← specialized subagents
    output-styles/                ← custom output styles
```

Add `.gitkeep` to empty directories so git tracks them. Remove `.gitkeep` once a real file is added.

**Gitignore entries** — append to `.gitignore` if not already present:

```text
# Claude Code — personal files
CLAUDE.local.md
.claude/settings.local.json
.claude/agent-memory-local/
.claude/state/
```

If `.claude/` already exists, warn the user and ask whether to overwrite or merge. Abort if the user declines.

## Detect stack

Detection runs in 3 passes — each adds detail the previous one missed.

**Pass 1 — Build system markers (root level):**

| Marker | Stack |
| ---- | ---- |
| `*.sln`, `*.vcxproj` | C++ / MSVC |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pyproject.toml`, `requirements.txt` | Python |
| `package.json` | Node.js / TypeScript |
| `pom.xml`, `build.gradle` | Java / Kotlin |
| `*.csproj` | C# / .NET |

**Pass 2 — File type census (full tree):**

Scan ALL file extensions recursively (excluding `node_modules`, `.git`, `build`, `dist`, `out`, `vendor`, `third_party`). Group by extension, count, identify languages:

```bash
find . -type f | grep -v node_modules | grep -v .git | \
  sed 's/.*\.//' | sort | uniq -c | sort -rn | head -20
```

Map extensions to stacks:

| Extensions | Stack |
| ---- | ---- |
| `.cpp`, `.h`, `.hpp`, `.cc`, `.cxx` | C++ |
| `.js`, `.jsx`, `.mjs` | JavaScript |
| `.ts`, `.tsx` | TypeScript |
| `.py` | Python |
| `.go` | Go |
| `.rs` | Rust |
| `.java`, `.kt` | Java / Kotlin |
| `.cs` | C# |
| `.scss`, `.css`, `.less` | Styles |
| `.html`, `.htm`, `.hbs`, `.ejs` | Templates |
| `.proto` | Protobuf / gRPC |
| `.sql` | SQL / Migrations |

If the census shows significant files (50+) in a language not found by Pass 1, report it as an **additional stack**. This catches embedded frontends (Sciter JS, Electron, embedded Python), code generation outputs, and polyglot repos.

**Pass 2b — Frontend detection (sets `has_frontend` flag):**

Light pass to detect user-facing frontend roots — presence triggers the end-of-run offer to run `/analyze-frontend`. Do NOT invoke the `frontend-detector` subagent here (it runs inside `/analyze-frontend` itself). Just flip a boolean.

Check for any of these at project root or one level deep (`apps/*/`, `packages/*/`, `web/`, `client/`, `frontend/`, `ui/`, `app/`, `projects/*/`):

| Signal | What it indicates |
| ---- | ---- |
| `package.json` + any of: `next.config.*`, `nuxt.config.*`, `angular.json`, `svelte.config.*`, `astro.config.*`, `vite.config.*`, `gatsby-config.*`, `remix.config.*`, `.eleventy.*`, `vue.config.*`, `polymer.json`, `ember-cli-build.js` | JavaScript/TypeScript frontend framework |
| `package.json` + `index.html` in same dir + no framework config | Vanilla JS or custom setup |
| `ui/**/*.js` alongside C++ with Sciter-specific imports | Embedded Sciter JS frontend |

If ANY hit — set `has_frontend = true` and collect the parent directories as `frontend_root_candidates[]`. Carry this through to the Report phase.

Do NOT try to classify frameworks here — that is `frontend-detector`'s job. We only need a yes/no + rough list of candidates.

**Pass 3 — Tooling and conventions:**

| What | Where to look |
| ---- | ---- |
| Formatter | `.clang-format`, `.prettierrc`, `pyproject.toml [tool.ruff]`, `rustfmt.toml`, `.editorconfig` |
| Linter | `.clang-tidy`, `.eslintrc*`, `ruff.toml`, `clippy.toml`, `.golangci.yml` |
| Tests | `jest.config.*`, `pytest.ini`, `*_test.go`, `*_test.cpp`, `*_test.rs` |
| CI/CD | `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`, `azure-pipelines.yml` |
| Git format | `git log --oneline -20` — detect `[PREFIX-XXXX]` or `type: description` |
| Branches | `git branch -r` — detect `PREFIX-XXXX` or `type/description` patterns |
| PR template | `.github/pull_request_template.md` |
| Ownership | `.github/CODEOWNERS` |

**Checkpoint format for multi-stack projects:**

```text
╭─ Detected Stack ────────────────────────────────────────────╮
│                                                             │
│  Primary       C++ (MSVC) — 650 files                      │
│  Secondary     JavaScript (Sciter) — 420 files              │
│  Styles        SCSS — 18 files                              │
│  Build         MSBuild (game-booster.sln)                   │
│  Package mgr   vcpkg                                        │
│  Formatter     clang-format                                 │
│  ...                                                        │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
```

## Detect monorepo

Three project types (detected during stack analysis):

**Type 1 — Single-stack:** one build system, flat modules, shared conventions.

**Type 2 — Clean monorepo:** distinct areas with different stacks (frontend/, backend/, infra/).

**Type 3 — Feature monorepo:** modules organized by feature, cross-cutting patterns span multiple modules.

## Discover modules

Where to look:

1. `$ARGUMENTS` path if provided
2. Auto-detect: `projects/*/`, `src/*/`, `packages/*/`, `apps/*/`, `cmd/*/`, `crates/*/`
3. Parse build system: `*.sln` projects, `go.work` modules, `pnpm-workspace.yaml` packages

## Detect logical layers

Group modules by shared concerns — even without creating rules yet, this informs the architecture section of CLAUDE.md.

How to detect:

1. **Group modules by shared file patterns** — if modules A, B, C all have `res/ui/**` files, they form a "UI layer"
2. **Check hub module imports** — which modules does the hub pull in? Group by concern
3. **Check solution/workspace grouping** — `.sln` folders, `workspace` sections, directory prefixes often reveal intended grouping
4. **Ask the user** — present detected groups and ask to confirm/adjust

```text
╭─ Detected Logical Layers ──────────────────────────────────╮
│                                                             │
│  Frontend layer (3 modules)                                 │
│    desktop, crash-handler, installer                        │
│                                                             │
│  Feature modules (20 modules)                               │
│    module-a, module-b, ...                                  │
│                                                             │
│  Common layer (2 modules)                                   │
│    common, version                                          │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
Confirm / adjust grouping?
```

## Analyze architecture

What to scan for:

- **Communication** — how do modules talk? (imports, events/signals, API calls, shared state)
- **Data flow** — how does data move through the system?
- **Hub modules** — which module integrates all others?
- **Shared code** — is there a common/ or shared/ module?

Do NOT deep-read every file. Scan headers/exports/public interfaces only.

## Create CLAUDE.md

Under 200 lines. Template:

```markdown
# Project Name

One-line description.

## Architecture

- How modules communicate (2-3 sentences, describe the data flow)
- Hub module and its role
- Cross-cutting patterns summary (if Type 3)

## Build & Run

- Toolchain, build, test, lint, run commands

## Project Structure

  module-a     — what it does (hub)
  module-b     — what it does
  shared/      — shared utilities
  (1 line per module, no internals)

## Code Conventions

- Global naming, formatting, patterns

## Git Conventions

- Branch/commit format
```

Use `@path` imports to reference existing docs instead of duplicating content:

```markdown
@README.md
@docs/architecture.md
```

**Critical:** CLAUDE.md describes the project overview. No module internals — those go in rules (created separately).

## Create module CLAUDE.md files (fan-out)

> Reference: read `docs/research-claude-md-rules.md` — rules for effective CLAUDE.md content
> Subagent definition: `agents/module-documenter.md` — per-module worker that this phase delegates to
> Fan-out pattern: `docs/reference-subagent-fanout-pattern.md` — decision heuristic and fan-in contract

Create `CLAUDE.md` inside each non-trivial module directory. Content is **purely additive** — never repeat root CLAUDE.md.

**Key principle: Patterns > Rules > Anti-patterns > Descriptions.** Claude follows concrete code examples more reliably than abstract rules, and both are more useful than descriptions.

**Which modules get one:**

| Category | Criteria | Create? |
| ---- | ---- | ---- |
| Hub | Integrates many modules, mixed concerns | Yes — detailed |
| Large | 20+ files, significant public API | Yes — full |
| Small | 5-19 files, has public interface | Yes — compact |
| Trivial | <5 files, wrappers, POC, version-only | No — skip |

The orchestrator (this skill) applies the filter above to produce `non_trivial_modules`. Deep per-module scanning and documentation writing DO NOT happen in the main session — they are delegated to parallel `module-documenter` subagents. This keeps main-session context small and lets documentation work proceed in parallel across modules.

**Execution — fan-out:**

For each module in `non_trivial_modules`, invoke the `module-documenter` subagent in parallel (fire all invocations in a single message with one `Agent` tool call per module — Claude Code runs them concurrently up to the session's parallel budget). Each invocation prompt MUST include:

| Field | Value |
| ---- | ---- |
| `module_path` | Absolute path to the module |
| `project_root` | Absolute path to the project root |
| `stack_summary` | One-line stack identity from Detect-stack phase |
| `project_type` | `single-stack` / `monorepo` / `feature-monorepo` |
| `hub_module_name` | Name of the designated hub module, if any |
| `rpc_layer_hint` | Names of RPC/API layer modules |
| `conventions_summary` | 3-5 bullets from the codebase-level conventions already detected |

The subagent spec in `agents/module-documenter.md` is the source of truth for the input contract and the return shape — do not re-describe it here.

**Fan-in contract:**

Each `module-documenter` returns two sections in its response (parsing is by heading):

1. `## Summary Row` — a YAML block with `name`, `path`, `files`, `lines`, `category`, `key_deps`, `key_reverse_deps`, `public_api_brief`, `kernel_type`. The orchestrator aggregates these into the module table shown in the end-of-run dashboard and the run report's Artefacts section.
2. `## CLAUDE.md Content` — the full markdown body ready for `<module_path>/CLAUDE.md`. If the subagent returned the literal string `SKIP`, the module is trivial-by-content and no file is written (its summary row still appears in the aggregated table with `trivial: true`).

After all subagents return, the orchestrator performs a single batch of FS writes — one `Write` per non-`SKIP` content. No retries, no validation here (validation is the `/validate-claude-docs` skill's job if invoked later).

If a subagent fails or returns unparsable output, log the failure in the run report's `Notes` section and proceed with the rest. Do NOT abort the entire phase on a single module's failure.

**Content priority per module type** (reminder — enforced by the subagent, documented here for the orchestrator's awareness):

| Module type | Must have | Nice to have |
| ---- | ---- | ---- |
| Hub | Asset inventory, UI structure, patterns | Anti-patterns |
| Large | Patterns, rules, anti-patterns, public API | Design direction |
| Small | Public API, patterns, dependencies | Anti-patterns |
| Legacy | "Bug fixes only" + anti-patterns | Nothing else needed |

**Why this structure:**

On a reference-monorepo baseline (see `.claude/state/reports/baseline-m2.md`), this phase accounted for 61% of total wall-clock time on a 64-module project. Fan-out to parallel subagents — each scanning ONE module in its own context — is what unlocks the M2 wall-clock and context-reduction targets. Generating the content inline in the main session is no longer acceptable; it is neither time-efficient nor context-efficient on real projects.

## Update settings

Update `.claude/settings.json` with stack-specific permissions. Include build/test/lint commands detected from the project.

## Report

The Report phase does two things: writes a persistent run report to `.claude/state/reports/init-project-<ts>.md` per [rules/report-format.md](../rules/report-format.md), and shows the on-screen dashboard.

**Timing capture — required for wall-clock metric:**

At the very start of the Scaffold phase (before any FS operation), capture the start timestamp:

```bash
Bash: START_TS=$(date +%s); RUN_TS=$(date -u +%Y%m%dT%H%M%SZ); DISPLAY_TS=$(date +%Y%m%d-%H%M%S); echo "START_TS=$START_TS RUN_TS=$RUN_TS DISPLAY_TS=$DISPLAY_TS"
```

Preserve these values in your working notes through the run. **REQUIRED** — also capture per-phase timestamps at each phase boundary. This is not optional; the Phase Timings table in the run report depends on it, and the table is what lets us measure bottlenecks over time (e.g. the M2 Generate-module-docs bottleneck was identified via these numbers).

**Per-phase timing template** — run at the START and END of every phase:

```bash
# At phase start:
Bash: PHASE_<NAME>_START=$(date +%s); echo "<NAME> started at $PHASE_<NAME>_START"

# At phase end:
Bash: PHASE_<NAME>_END=$(date +%s); PHASE_<NAME>_SEC=$((PHASE_<NAME>_END - PHASE_<NAME>_START)); echo "<NAME> took $PHASE_<NAME>_SEC s"
```

Phases to time (matching the sequence diagram notes):

| `<NAME>` | Phase |
| ---- | ---- |
| `SCAFFOLD` | Scaffold `.claude/` + gitignore |
| `DETECT_STACK` | Detect stack (3 passes + Pass 2b frontend) |
| `DETECT_MONOREPO` | Detect monorepo type |
| `DISCOVER_MODULES` | Discover modules |
| `DETECT_LAYERS` | Detect logical layers |
| `ANALYZE_ARCH` | Analyze architecture |
| `GEN_ROOT` | Generate root CLAUDE.md |
| `GEN_MODULES` | Generate module CLAUDE.md files (fan-out) |
| `SETTINGS` | Update settings.json |
| `REPORT` | Write report + show dashboard |

Report the timing of each phase in the `## Phase Timings` table. Do NOT fall back to approximations — if you forgot to capture one, acknowledge it in the report's `## Notes` section with `timing_missing=<phase-name>` rather than estimating.

**Report generation (at the start of this phase):**

```bash
Bash: END_TS=$(date +%s); echo "wall_clock_sec=$((END_TS-START_TS))"
```

Then collect:

- Stack summary (from Detect stack phase)
- Module count (from Discover modules phase)
- Artefact list — every file you created or touched, with `wc -l` line counts
- Phase timings (from your REQUIRED per-phase timestamps — see above)
- Next-step recommendations (same content that goes into the dashboard)

Write the report file to `.claude/state/reports/init-project-<DISPLAY_TS>.md`.

**REQUIRED — exact first-line format** (not negotiable, do NOT use JSON, do NOT rename keys):

```text
<!-- report: skill=init-project ts=<ISO-UTC> wall_clock_sec=<int> modules=<int> artefacts=<int> stack=<short-string> project_type=<single-stack|monorepo|feature-monorepo> -->
```

Hard rules:

- **Prefix is literal `<!-- report:`** (with a trailing space before the first key) — NOT `<!-- meta:`, not `<!-- run:`, not `<!-- info:`.
- **Format is `key=value` pairs separated by spaces** — NOT a JSON object. Do NOT use `{ "skill": "..." }` syntax.
- **Key names exactly as listed** — `ts` (NOT `run_ts`), `wall_clock_sec`, `modules`, `artefacts` (NOT `artefact_count`), `stack`, `project_type`. Optional extras like `has_frontend=true`, `mode=<mode>` are allowed AFTER the required keys.
- **No trailing comma, no quoted values** unless the value itself contains spaces (in which case wrap as `stack="typescript + sciter js"`).
- **Single line** — the entire metadata comment is one line, no embedded newlines.

The rule [rules/report-format.md](../rules/report-format.md) is the source of truth; this skill's instructions above must match it. If you are unsure, re-read the rule file.

Body sections after the metadata comment must include, in this order: `# <Skill> — Report (<date>)` H1, `## Summary`, `## Phase Timings`, `## Artefacts`, `## Next-step Recommendations`, optional `## Notes`.

If the target project does not have `.claude/state/reports/`, create it first (`.claude/state/` should already exist from the Scaffold phase; add `reports/` as a subdirectory now).

**On-screen dashboard (shown to user after file write):**

```text
╭─ /init-project Complete ────────────────────────────────────╮
│                                                             │
│  Type         <project type>                                │
│  Stack        <detected stack>                              │
│  Duration     <wall_clock_sec>s                             │
│  CLAUDE.md    root: N lines                                 │
│  Modules      N module CLAUDE.md (M skipped as trivial)     │
│  Settings     ✓  configured                                 │
│  Report       ✓  .claude/state/reports/init-project-...md   │
│                                                             │
╰─────────────────────────────────────────────────────────────╯

Next steps:
  /create-docs rule <pattern>    Add rules for project patterns
  /create-mermaid sequence       Create data flow diagram
```

**Conditional: if Pass-2b set `has_frontend = true`** — append this BEFORE the generic Next steps section:

```text
  ┌─ Frontend detected ───────────────────────────────────────┐
  │                                                           │
  │  Candidate root(s):  <relative path>                      │
  │                      <relative path>                      │
  │                                                           │
  │  Run /analyze-frontend to generate:                       │
  │    .claude/rules/frontend-design-system.md                │
  │    .claude/rules/frontend-components.md                   │
  │    .claude/docs/reference-architecture-frontend.md        │
  │    .claude/docs/reference-component-inventory.md          │
  │    .claude/sequences/frontend-data-flow.mmd               │
  │                                                           │
  │  [y] run now   [n] skip   [d] defer (remind later)        │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
```

If user chooses `[y]` — invoke `/claude-docs-creator:analyze-frontend` in-session (pass the first candidate's absolute path as `frontend-path` argument if multiple candidates exist). If `[n]` / `[d]` — skip, and add a `## Notes` entry to the run report: `Frontend(s) detected at <paths> but /analyze-frontend was declined — user can run it later`.

The Report-phase output on-screen must match the content in the saved file (same metrics, same next-steps) — the file is a persistent copy, not a separate artefact.
