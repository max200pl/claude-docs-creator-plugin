# Changelog

All notable changes to the `claude-docs-creator` plugin. Format loosely follows [Keep a Changelog](https://keepachangelog.com) and [Semantic Versioning](https://semver.org).

## 0.11.2 — 2026-04-21

Auto-patch-bump in the publish GitHub Action — removes the "forgot-to-bump" mistake class.

### Added

- `.github/workflows/publish-plugin.yml` now inspects private and public plugin versions before sync. If a plugin-layer change reached `main` without an explicit bump in `.claude-plugin/plugin.json`, the Action automatically bumps **patch** in the public repo's manifests (`plugin.json` + both fields in `marketplace.json`). Public commit message documents the auto-bump with the before/after versions. Manual `minor`/`major` bumps in the private repo are detected (version mismatch) and respected — no double-bump.

### Changed

- Private and public plugin versions may diverge by patch increments after the first auto-bump. This is by design: private tracks author-intent releases (minor/major bumps), public tracks every distribution checkpoint. Release-engineering discipline for `minor`/`major` bumps stays fully manual — edit `plugin.json` in the private repo as before.

### Release-workflow summary

| Change type | Where author edits version | What happens |
| ---- | ---- | ---- |
| Docs typo, small fix, dependency tweak | — (don't edit version) | On push, GHA auto-bumps patch in public. |
| New feature, scoped rule, new subagent | — (don't edit version — auto-patch is fine) OR manual bump minor in private | Public advances to the same minor as private, or to next patch. |
| Breaking change to skill API | Manual bump major in private's `plugin.json` before push | Public matches private's new major version. |

## 0.11.1 — 2026-04-21

Public-distribution preparation + /init-project hotfix.

### Added

- `LICENSE` (MIT) at repo root.
- `CHANGELOG.md` — version history.
- `.github/workflows/publish-plugin.yml` — GitHub Action that syncs the plugin-layer (skills/, agents/, rules/, docs/, sequences/, hooks/, output-styles/, .claude-plugin/, README, LICENSE, CHANGELOG) from the private dev repo to a public distribution repo on each `main` push.

### Fixed

- **B3** — `/init-project` Interactive Wizard no longer asks the user what language to use for generated docs. Generated docs MUST be English per `rules/docs-english-only.md`; the question was redundant and could produce non-compliant output.
- **B4** — `/init-project`, `/update-docs`, `/analyze-frontend` Report-phase instructions now inline the exact first-line metadata template with negative constraints. Previous indirection through "see `rules/report-format.md`" led to a real divergence where one LLM emitted JSON-in-comment with alias keys (`run_ts`, `artefact_count`) instead of the key=value format (`ts`, `artefacts`).
- **G8** — per-phase timestamp capture in all three orchestrator skills is now REQUIRED (was "optional but preferred"). A bash template is inlined to reduce ambiguity.

### Changed

- `plugin.json` and `marketplace.json` `homepage` + `repository` fields updated to point to the public distribution repo URL.

### Housekeeping

- Scrubbed `pc_cleaner` product-name references from 3 public-layer files (`.claude/docs/milestones.md`, `agents/module-documenter.md`, `skills/init-project/SKILL.md`) per `rules/no-project-context.md`. Replaced with generic "reference monorepo" / `<project>/<module-name>` placeholders. Historical data in gitignored `.claude/state/reports/` retains the real name as an internal record.

## 0.11.0 — 2026-04-21

M8 — Frontend Analysis Suite + `/sleep` Batch 1.

### Added

- `skills/analyze-frontend/SKILL.md` — orchestrator: detect frontend root(s), fan out to 5 specialist subagents in parallel per frontend, collect results, write scoped `.claude/` artefacts, update root `CLAUDE.md` Architecture section, emit run report.
- `sequences/analyze-frontend/analyze-frontend.mmd` — flow diagram.
- Six new subagents in `agents/`: `frontend-detector` (gating), `tech-stack-profiler`, `design-system-scanner`, `component-inventory`, `data-flow-mapper`, `architecture-analyzer`.
- `/init-project` Pass-2b frontend detection: sets `has_frontend` flag + candidate roots; end-of-run dashboard offers `/analyze-frontend` (y/n/d) when applicable.
- `/update-docs --refresh frontend[:area]` flag — thin wrapper that delegates to `/analyze-frontend [--only <area>]`.
- `/status` extension: conditional "Frontend Analysis" section with per-artefact freshness + targeted `--refresh` suggestion on stale.
- `/sleep` Batch 1 — four new lint checks surfaced by `/distill`: orchestrator skills must reference `rules/report-format.md`; `agents/*.md` frontmatter schema (`name`, `description`, `tools`, `model`); version-bump-pending (committed + uncommitted delta since last `plugin.json` version change); sequence-diagram subagent participants must match a real agent file.

### Changed

- `skill-scopes.md`, `two-layer-architecture.md`, `menu/SKILL.md`, `architecture-overview.mmd` — manifests reflect new skill + 6 new public agents.

## 0.10.0 — 2026-04-21

Close M2: subagent delegation verified.

### Summary

Fan-out refactor in `/init-project` Generate-module-docs phase delivered unexpected but valuable outcome on reference-monorepo baseline: wall-clock parity (+2%, within noise) but +41% richer module docs and 5 real codebase issues surfaced via subagent Notes. Reframed M2 success criteria from wall-clock reduction to context reduction + depth. Detailed comparison in internal `.claude/state/reports/postchange-m2.md`.

## 0.9.1 — 2026-04-21

Fan-out `module-documenter` in `/init-project` Generate phase.

### Added

- `agents/module-documenter.md` — read-only per-module subagent returning `{summary_row YAML, claude_md_content markdown body}` with `SKIP` sentinel for trivial modules.
- `.claude/docs/subagent-fanout-pattern.md` — toolkit-maintainer reference documenting the fan-out decision heuristic, return-shape contract, pitfalls, checklist, and M8 applicability.

### Changed

- `skills/init-project/SKILL.md` Generate-module-docs phase — delegates per-module deep-scan + `CLAUDE.md` generation to parallel `module-documenter` subagents via the fan-out pattern.
- `sequences/init-project/generation-and-report.mmd` — `loop` → `par` block.
- `.claude/agents/skill-architect.md` — gains explicit fan-out rule + report-phase rule.

## 0.9.0 — 2026-04-21

Report-phase for orchestrator skills.

### Added

- `rules/report-format.md` — public-layer rule: report path (`.claude/state/reports/<skill>-<ts>.md`), filename convention, first-line machine-diff metadata contract, required body sections.
- Report-phase in `/init-project` and `/update-docs` — persists run dashboard to a gitignored file per the new rule.

### Changed

- `/init-project` gitignore block now includes `.claude/state/` so generated reports never accidentally commit.

## 0.8.0 — 2026-04-20

Initial plugin packaging (M5 — partial).

### Added

- `.claude-plugin/plugin.json` manifest.
- `.claude-plugin/marketplace.json` marketplace manifest with `source: "./"` so the repo IS the marketplace.
- Plugin-layout migration from `.claude/<subdir>/` to repo-root `<subdir>/` for all public-layer content.
- `hooks/hooks.json` extracted from `.claude/settings.json`, paths use `${CLAUDE_PLUGIN_ROOT}`.

### Known

- No LICENSE file yet (to be added in 0.11.1).
- No CHANGELOG yet (to be added in 0.11.1).
- Release discipline (semver tags, migration docs) formalized in 0.11.1.
