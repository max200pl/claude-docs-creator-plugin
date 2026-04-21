# Report Format Convention

## Rule

Every orchestrator skill that runs an end-to-end flow (`/init-project`, `/update-docs`, future `/analyze-frontend`, etc.) must persist its final dashboard to a report file so runs are comparable over time.

On-screen dashboards are ephemeral. Report files give `/distill`, `/status`, and humans a permanent, diffable record of what a skill did, how long it took, and what it produced.

## When to Apply

Applies to skills that:

- Orchestrate multiple phases (scaffold, detect, generate, verify)
- Produce multiple artefacts (files created, modules processed)
- Have a user-facing end-of-run dashboard

Does NOT apply to:

- One-shot utility skills with a single action (`/menu`, `/create-mermaid` for a single diagram)
- Skills that run in seconds with no measurable phases

## File Location

```text
<project-root>/.claude/state/reports/<skill>-<YYYYMMDD>-<HHMMSS>.md
```

Where `<project-root>` is the cwd at the time the skill runs — the **target project** for public skills, the **toolkit repo** for self-dogfood runs. Skills always write relative to cwd; never to the plugin root.

`.claude/state/` is gitignored by the toolkit convention (established in [rules/docs-folder-structure.md](docs-folder-structure.md) and enforced in `/init-project`'s gitignore block). Reports are per-run, ephemeral, and must never commit.

## Filename Convention

- Pattern: `<skill>-<YYYYMMDD>-<HHMMSS>.md`
- Timestamp: local time of the machine running the skill, NOT UTC — human-readable for the operator
- Example: `init-project-20260421-143022.md`
- No spaces, no unicode, no colons — filename must be portable across filesystems
- Two runs on the same second collide; skills must append `-<N>` suffix (`init-project-20260421-143022-2.md`) if the primary name already exists

## Required First Line — Machine-Diff Metadata

The first line of every report is an HTML comment containing key=value metadata. Invisible in rendered markdown but greppable.

**Exact format — not negotiable:**

```text
<!-- report: skill=<name> ts=<iso-8601> wall_clock_sec=<int> <unit-count-key>=<int> artefacts=<int> stack=<short> -->
```

Hard rules on format:

- **Prefix is literal** `<!-- report:` (space after colon is part of the key/value syntax, not the prefix). NOT `<!-- meta:`, NOT `<!-- run:`, NOT `<!-- info:`.
- **Format is `key=value` pairs separated by spaces** — NOT a JSON object. Do NOT emit `{ "key": "value" }`.
- **Key names exactly as listed below** — no aliases (do NOT use `run_ts` for `ts`, do NOT use `artefact_count` for `artefacts`).
- **Single line** — the entire metadata comment is one line, no embedded newlines.
- Quoted values only when the value contains a space: `stack="typescript + sciter js"`.

Required keys:

| Key | Type | Meaning |
| ---- | ---- | ---- |
| `skill` | string | Skill name without leading slash — `init-project`, `update-docs`, `analyze-frontend` |
| `ts` | ISO 8601 | `2026-04-21T14:30:22Z` — UTC, machine-sortable. NAME MUST BE `ts`, not `run_ts`. |
| `wall_clock_sec` | int | Total time skill ran, in seconds |
| `<unit-count-key>` | int | Units processed by the skill. Per skill: `modules` for `/init-project` and `/update-docs`; `frontends` for `/analyze-frontend`. Both are valid; use whichever describes the skill's unit of work. |
| `artefacts` | int | Files created OR modified by the skill. NAME MUST BE `artefacts`, not `artefact_count`. |

Optional keys:

| Key | Type | Meaning |
| ---- | ---- | ---- |
| `stack` | string | Primary stack detected — `typescript+vite`, `go+cobra`, `mixed` |
| `project_type` | string | `single-stack` / `monorepo` / `feature-monorepo` |
| `mode` | string | Skill-specific mode — `report` / `auto` / `interactive` for `/update-docs` |

Why: `grep "^<!-- report:" .claude/state/reports/*.md` yields a one-line-per-run table. Used by `/distill` to find trends ("init-project time grew 30% over last 5 runs"), by `/status` to show latest-run summary, by humans to eyeball deltas.

## Required Body Sections

Under the metadata comment, the report body uses standard markdown and mirrors the on-screen dashboard.

| Section | Required | Content |
| ---- | ---- | ---- |
| `# <Skill> — Report (<date>)` | yes | H1 title with human-readable run date |
| `## Summary` | yes | Project path, stack, duration, module count, artefact count — bulleted |
| `## Phase Timings` | yes | Table: phase name, duration (sec), short note |
| `## Artefacts` | yes | Table: path, line count, category (overview / rule / config / module-doc) |
| `## Next-step Recommendations` | yes | Bulleted list — same content as the on-screen dashboard's next-steps section |
| `## Raw Metrics` | optional | JSON code block with full structured data — for future `/distill` consumption |
| `## Notes` | optional | Any surprises, warnings, or user overrides during the run |

The on-screen dashboard and the report body should present the same information. If the dashboard changes, the report format changes with it.

## Obeying Output-Format Rules

Box-drawing, severity tags, and alignment from [rules/output-format.md](output-format.md) apply to the **on-screen** dashboard. The **report file** uses plain markdown — tables, headings, bullets. No box-drawing in files (they render poorly in `.md` renderers and hurt diff-ability).

## Minimal Example

```markdown
<!-- report: skill=init-project ts=2026-04-21T14:30:22Z wall_clock_sec=47 modules=18 artefacts=22 stack=typescript+vite -->

# init-project — Report (2026-04-21 14:30)

## Summary

- Project: `/Users/me/Projects/my-app`
- Stack: TypeScript + Vite (single-stack SPA)
- Duration: 47s
- Modules discovered: 18
- Artefacts created: 22 files, 1,247 lines

## Phase Timings

| Phase | Duration | Notes |
| ---- | ---- | ---- |
| Scaffold | 2s | 9 directories, 5 files |
| Detect stack | 5s | 3 passes |
| Detect monorepo | 3s | single-stack |
| Discover modules | 18s | 18 modules |
| Detect layers | 4s | 3 layers |
| Generate CLAUDE.md | 12s | 187 lines |
| Generate module docs | 3s | 18 files |
| Report | <1s | this file |

## Artefacts

| Path | Lines | Category |
| ---- | ---- | ---- |
| `CLAUDE.md` | 187 | project-overview |
| `.claude/settings.json` | 12 | config |
| `modules/core/CLAUDE.md` | 42 | module-overview |
| ... | ... | ... |

## Next-step Recommendations

- Create rules for 2 dominant patterns surfaced during discovery
- Consider adding `/validate-claude-docs` to CI
- Review auto-detected layer boundaries (3 layers — confirm via `/update-docs report`)
```

## How Skills Produce Timestamps and Durations

Skills capture wall-clock via `Bash: date +%s` at the start of phase 1 and at the start of the Report phase. The difference is `wall_clock_sec`. Individual phase timings are captured the same way per-phase.

For `ts` (ISO 8601 UTC), skills run `Bash: date -u +%Y-%m-%dT%H:%M:%SZ` once at skill start.

Skills SHOULD NOT rely on a hook to generate timestamps — the skill owns its own report. See [.claude/docs/subagent-fanout-pattern.md](../.claude/docs/subagent-fanout-pattern.md) and the rationale in M2 of `.claude/docs/milestones.md` for why reporting is in-skill rather than hook-driven.

## Retention

No automatic rotation in MVP. Reports accumulate in `.claude/state/reports/` until the user deletes them. Since `.claude/state/` is gitignored, this is safe — deletion is always reversible via `git` only for committed files, and reports never commit.

If `/distill` consumption becomes load-bearing, a future rule may add retention (`keep-last-N-runs-per-skill`). Not in M2 scope.
