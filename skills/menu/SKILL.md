---
name: menu
scope: api
description: "Show available /claude-docs-creator:* commands plus a quick status summary of the current project's .claude/. Discovery screen for end users who installed the plugin — lists api + shared skills only. Toolkit-internal skills (sleep, distill, create-mermaid, research, create-tutorial) are intentionally hidden."
user-invocable: true
---

# Menu

Discovery hub for end users of the `claude-docs-creator` plugin. Shows what the plugin exposes, a compact status of the current project's `.claude/`, and one suggested next action.

## What to Show

### Available commands

Display as a formatted table:

```text
╭─────────────────────────────────────────────────────────────╮
│  claude-docs-creator                                        │
╰─────────────────────────────────────────────────────────────╯

  ┌─ Documentation (api) ─ run on your project ───────────────┐
  │                                                           │
  │  /init-project <path>         Initialize .claude docs     │
  │  /create-docs <type> [name]   Create rule/skill/agent/etc │
  │  /update-docs <path> [mode]   Detect drift + refresh docs │
  │  /validate-claude-docs <path> Audit .claude structure     │
  │  /status <path>               Coverage + staleness stats  │
  │  /check-links [path]          Find broken .md/.mmd links  │
  │                                                           │
  └───────────────────────────────────────────────────────────┘

  ┌─ Frontend analysis (api) ─ one-stop for SPAs ─────────────┐
  │                                                           │
  │  /analyze-frontend [path]     Detect stack + persist JSON │
  │                               analysis to .claude/state/  │
  │  /create-frontend-docs        JSON → component-creation-  │
  │                               template.md + references    │
  │  /update-frontend-docs <area> Area-scoped refresh of      │
  │                               frontend artefacts          │
  │                                                           │
  └───────────────────────────────────────────────────────────┘

  ┌─ Authoring (api + shared) ─ helper skills ────────────────┐
  │                                                           │
  │  /create-sequences <name>   Mermaid sequence diagram in   │
  │                             .claude/sequences/            │
  │  /create-steps <topic>      Step-by-step runbook w/       │
  │                             rollback                      │
  │  /menu                      This screen                   │
  │                                                           │
  └───────────────────────────────────────────────────────────┘

  Agents (@name to delegate)
    @doc-reviewer              Verify docs match actual code
    @module-documenter         Per-module scan (used by /init-project)
    @frontend-detector         Enumerate frontend roots (gating)
    @tech-stack-profiler       Profile stack (Wave 1)
    @design-system-scanner     Tokens / CSS vars / theme
    @component-inventory       Components + conventions
    @data-flow-mapper          State + API + auth + forms
    @architecture-analyzer     Folder layout / routing / SSR
    @framework-idiom-extractor Framework-specific idioms

  Reference (in this plugin's docs/)
    reference-subagent-fanout-pattern   Fan-out pattern for orchestrators
    reference-context-compression       Context savings strategy
    reference-drift-catalog             /update-docs drift taxonomy
    reference-drift-repairs             /update-docs apply-phase mechanics
    reference-keybindings               Recommended user shortcuts
    checklist-project-docs-review       Review quality of generated docs
    how-to-create-docs                  Doc authoring recipes
    how-to-create-mermaid               Mermaid authoring guide
    how-to-slim-claude-md               Shrink CLAUDE.md via scoped rules
    how-to-structure-docs               Split/merge/promote files in docs/
    tutorial-getting-started            30-min onboarding
    tutorial-paths-scoping              `paths:` glob cheatsheet
    tutorial-batch-remediation          Close validate-docs warnings

  Invocation: all commands use the `/claude-docs-creator:<skill>` form
  after plugin install (or direct `/<skill>` inside a session that has
  the plugin active).
```

### Quick status

After the commands table, show a compact summary scanned from the current project. Gather via filesystem:

```text
  Status — <project-name>
    CLAUDE.md        ✓  <N> lines   (or  ✗  missing)
    Rules            <N> files  (<N> scoped, <N> global)
    Skills           <N>  (user-authored — excluding plugin)
    Sequences        <N>
    Settings         ✓  configured  (or  ✗  missing)
    Frontend docs    ✓  N artefacts (or  —  none yet)
    Last commit      <relative time>
```

Use `✓` for healthy, `✗` for missing/broken, `—` for "nothing to check", `⚠` for warnings.

### Suggested next action

Based on state, suggest ONE next action:

| State | Suggestion |
| ---- | ---- |
| No `CLAUDE.md` or only template placeholders | → `/init-project <path>` |
| `.claude/` exists but no rules | → `/create-docs rule <name>` to scope-load patterns |
| Rules exist but no frontend analysis and project has package.json | → `/analyze-frontend` |
| Analysis JSON exists but artefacts missing | → `/create-frontend-docs` |
| Everything looks good | → `/validate-claude-docs <path>` |
| Issues from last validate | → `/validate-claude-docs <path> fix` |
| Docs haven't been refreshed in > 30 days | → `/update-docs <path>` |

Display in a box:

```text
╭─ Next step ─────────────────────────────────────────────────╮
│  Run /init-project to set up documentation for this project │
╰─────────────────────────────────────────────────────────────╯
```

## How to Gather Status

1. `CLAUDE.md` — check exists, count lines, grep for `{{` placeholders
2. Rules — glob `.claude/rules/*.md`, count, check which have `paths:`
3. Skills — glob `.claude/skills/*/SKILL.md` in the PROJECT (plugin skills don't count)
4. Sequences — glob `.claude/sequences/**/*.mmd`, count
5. Settings — check `.claude/settings.json` exists and is valid JSON
6. Frontend artefacts — glob `.claude/state/frontend-analysis.json` + `.claude/docs/reference-component-creation-template.md`
7. Git — `git log -1 --format="%cr"` for last commit time

## What This Skill Does NOT Do

- List toolkit-internal commands (`/sleep`, `/distill`, `/create-mermaid`, `/research`, `/create-tutorial`) — those live in the toolkit's private dev repo and are not exposed to end users.
- Auto-run any action — it's a passive discovery surface. Actions are the user's choice.
- Fix things it flags in the status dashboard — flagging is informational; each fix has its own skill.
