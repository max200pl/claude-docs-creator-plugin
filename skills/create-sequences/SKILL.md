---
name: create-sequences
scope: api
description: "Create or update a Mermaid sequence diagram (.mmd) in a target project's .claude/sequences/. User-facing wrapper for documenting flows — data flow between components, service interactions, deploy pipelines, state machines. Writes to <project>/.claude/sequences/<name>.mmd with the plugin's mermaid-style conventions."
user-invocable: true
argument-hint: "<name> [description]"
---

# Create Sequence Diagram

> **Flow:** read `sequences/create-sequences.mmd` — source of truth for execution order
> Authoring guide: read `docs/how-to-create-mermaid.md` — how to pick participants, sketch the flow, use `alt`/`par`/`opt` blocks
> Style rules: read `rules/mermaid-style.md` — neutral theme, no hardcoded colors, participant naming, block depth limits
> Output rules: read `rules/output-format.md`

Create a Mermaid sequence diagram and save it to the target project's `.claude/sequences/<name>.mmd`. This is a **user-facing skill** that produces **project documentation** — not to be confused with the internal `/create-mermaid` tool (which toolkit maintainers use to author flow diagrams inside the toolkit repo itself).

Use this when:

- Documenting a request/response flow between services (frontend → API → DB)
- Diagramming a deployment pipeline (rsync → SSH → remote compose)
- Capturing a user-action data flow (click → state change → API call → UI update)
- Describing a background job or cron sequence
- Recording the step-by-step of an onboarding or auth handshake

## What this skill creates

- `<project-root>/.claude/sequences/<name>.mmd` — a single Mermaid sequence diagram file with:
  - YAML frontmatter including `title`
  - Neutral theme directive per `rules/mermaid-style.md`
  - Declared participants at the top (actor for humans; participant for systems)
  - Notes for phase labels — no step-number prefixes
  - `alt/else/end`, `opt/end`, `par/end`, `break/end` for branching when needed

## What this skill does NOT create

- Architecture flowcharts (use a different Mermaid diagram type — `flowchart` — not a sequence)
- State machines or ER diagrams (same — different Mermaid types)
- Diagrams inside SKILL.md or CLAUDE.md (those are for skill authors, not user projects)
- Diagrams in the toolkit repo itself (that's the internal `/create-mermaid` skill's job)

For those cases: either use a different `.mmd` type in a standalone file, OR use the internal `/create-mermaid` skill (if you are a toolkit contributor with access to the private dev repo).

## Usage

```text
/create-sequences <name>
/create-sequences <name> "<description>"
/create-sequences user-login "end-to-end login flow including OAuth redirect and session cookie set"
```

The `<name>` becomes the filename (`<name>.mmd`), slugified to kebab-case if needed. Provide a short description (optional) to help Claude choose the right participants and level of detail.

## Interactive Wizard

Like other orchestrator skills, this one pauses at key checkpoints.

| After phase | What to show | What to ask |
| ---- | ---- | ---- |
| Detect participants | Candidate participants (actors + systems) gathered from `<description>` + project context | Confirm / add / remove |
| Sketch flow | High-level message list in a box | Approve / edit / reorder |
| Draft diagram | The proposed `.mmd` content | Write as-is / iterate once |
| Write | Path + file size | — |

## Reference

### Phase: Preflight

Capture `START_TS` for the Report phase:

```bash
Bash: START_TS=$(date +%s); DISPLAY_TS=$(date +%Y%m%d-%H%M%S); echo "START_TS=$START_TS DISPLAY_TS=$DISPLAY_TS"
```

Check that `.claude/sequences/` exists in cwd. If absent, the project has not been `/init-project`-ed — stop and point the user to `/init-project` first.

### Phase: Detect participants

Ask the user (or infer from `<description>`) what participants the flow involves. Typical categories:

- **Actor** (human): User, Operator, Admin, Caller
- **UI / Client**: Browser, Mobile App, Desktop App, CLI
- **Framework runtime**: Next server, Express, SvelteKit endpoint, Sciter runtime
- **Backend service**: API, Auth Service, WebSocket Server
- **Data stores**: DB, Cache, Queue, Object Storage
- **External**: OAuth Provider, Payment Gateway, Third-party API
- **Infrastructure**: Load Balancer, Reverse Proxy, Container

Follow `rules/mermaid-style.md` participant-naming conventions — short but meaningful (`API` > `api-gateway-v2`; `DB` > `postgres-main-cluster`).

### Phase: Sketch flow

Before writing the full `.mmd`, sketch the high-level message list (5-15 arrows). This is cheap to review and prevents rewriting after the diagram is drawn.

Format:

```text
1. User -> Browser: click "Sign in with Google"
2. Browser -> API: GET /auth/google-redirect
3. API -> OAuth: redirect with client_id
4. OAuth -> Browser: Google consent screen
...
```

### Phase: Draft diagram

Expand the sketch into a full `.mmd` file. Apply `rules/mermaid-style.md`:

- Frontmatter `title:` matches the user's name + description
- `%%{init: {'theme': 'neutral'}}%%` directive
- No hardcoded colors, no `rect rgb(...)`, no inline styles
- No step-number prefixes in note labels (per `rules/no-step-numbers.md`)
- `alt/else/end` for branching; `opt/end` for optional side-effects; `par/end` for concurrency; `break/end` for early exit
- `<br/>` for multi-line note content inside `note over` blocks (NOT in `participant X as Label` aliases — plain text only in aliases)
- Avoid semicolons (`;`) in `note over` text and arrow message text — Mermaid treats `;` as a statement separator in some renderers
- Max 2 levels of subgraph nesting

Typical template:

```text
---
title: "<name> — <description>"
---
%%{init: {'theme': 'neutral'}}%%
sequenceDiagram
    actor User
    participant Browser
    participant API
    participant DB

    User->>Browser: <action>
    Browser->>API: <request>
    API->>DB: <query>
    DB-->>API: <result>
    API-->>Browser: <response>
    Browser-->>User: <visible outcome>

    alt <condition>
        ... branch A ...
    else
        ... branch B ...
    end
```

### Phase: Write

Write to `<project-root>/.claude/sequences/<slugified-name>.mmd`.

If a file at that path already exists, ask the user before overwriting: diff the existing + proposed, offer `[o]verwrite / [m]erge / [c]ancel`.

### Phase: Report (optional for short runs)

For this skill — a small one-shot — a full run report is overkill. Emit a compact on-screen confirmation:

```text
╭─ /create-sequences Complete ────────────────────────────────╮
│                                                             │
│  File         .claude/sequences/<name>.mmd                  │
│  Participants N                                             │
│  Messages     N                                             │
│  Duration     <sec>s                                        │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
```

No separate report file for single-diagram runs.

## Relationship to `/create-mermaid` (internal)

`create-mermaid` is a toolkit-internal skill (`.claude/skills/create-mermaid/`) used by maintainers to author diagrams INSIDE the toolkit repo itself (under `sequences/`, `.claude/sequences/`, `.claude/docs/`). It handles all Mermaid diagram types (sequence, flowchart, state, ER, mindmap) and is not visible to end users.

`create-sequences` (this skill) is the user-facing API wrapper focused on ONE specific use case: sequence diagrams in a user's `.claude/sequences/`. It applies the same style rules and would follow the same authoring steps — but its scope is narrower and purpose-built for documenting project flows.

If you need a flowchart, state diagram, or other Mermaid type in your project: author it by hand using `rules/mermaid-style.md` as the style guide. A future `/create-flowchart` or similar could mirror this skill's pattern for other diagram types.

## What This Skill Does NOT Do

- Mutate code or sources in the project — pure documentation writer
- Generate non-Mermaid diagrams (PlantUML, DrawIO, Excalidraw) — Mermaid only
- Crawl the project to infer the flow — the user provides the description; this skill is a drafting tool, not an analyzer. For analysis-derived data-flow diagrams, use `/analyze-frontend`, which emits `frontend-data-flow.mmd` via the `data-flow-mapper` subagent.
- Auto-embed the new diagram in CLAUDE.md — the user can add a reference manually if they want
