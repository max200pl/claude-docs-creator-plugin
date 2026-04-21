---
name: create-tutorial
scope: shared
description: "Generate an ELI5 step-by-step tutorial for a toolkit concept, skill, workflow, or any topic. Produces docs/tutorial-<slug>.md with prerequisites, numbered steps, a hands-on exercise, verification, common mistakes, and next steps. Audience level scales from beginner to reference cheatsheet."
user-invocable: true
argument-hint: "<topic> [level]"
---

# Create Tutorial

> **Flow:** read `sequences/create-tutorial.mmd` — source of truth for execution order
> Style rules: read `rules/markdown-style.md`
> Output rules: read `rules/output-format.md`

Turn a toolkit capability (or any topic) into a learnable, copy-paste-ready walkthrough. Solves the "too many tools, nobody knows which to use" problem that emerges once a `.claude/` tree has more than ~10 skills or ~10 rules.

## Usage

```text
/create-tutorial <topic>                     # default level: beginner
/create-tutorial <topic> beginner
/create-tutorial <topic> intermediate
/create-tutorial <topic> reference
```

**Examples:**

- `/create-tutorial getting-started` — master tour of the whole toolkit
- `/create-tutorial hooks` — deep dive on lifecycle hooks
- `/create-tutorial update-docs-workflow` — when/how to use `/update-docs`
- `/create-tutorial paths-scoping reference` — compact cheatsheet for `paths:` frontmatter

If no topic is given, ask the user which concept, skill, or workflow to document.

## Audience Levels

The level argument controls depth and length. Same topic, different tutorial.

| Level | Assumes | Length | When to pick |
| ---- | ---- | ---- | ---- |
| `beginner` (default) | No Claude Code background. Defines every term. | 200-400 lines | Onboarding a new developer, or documenting a new capability |
| `intermediate` | Knows skills, rules, sequences. | 100-200 lines | Explaining a workflow that composes known primitives |
| `reference` | Knows the topic but needs a cheatsheet. | 50-100 lines | Daily-use lookup — patterns, flags, gotchas |

Pass the level into the tutorial's frontmatter so future runs and readers know the target.

## Template

Every tutorial follows this structure. Deviate only with a reason.

```markdown
---
topic: <slug>
level: beginner | intermediate | reference
date: YYYY-MM-DD
estimated-time: <N> minutes
---

# Tutorial: <Title>

## What & Why

<1-3 sentences: concrete result the reader will have at the end, plus the
 motivation — what problem this solves.>

## Prerequisites

- <specific tool, version, or knowledge required>
- <link to a previous tutorial if it exists>

## Core Concepts  <!-- beginner level only -->

<Define every term that will appear in the steps. Keep it to 5-10 terms.>

## Steps

### Step 1 — <imperative action>

Action:

\`\`\`bash
<exact command or file edit>
\`\`\`

Expected output:

\`\`\`text
<what the learner will see on success>
\`\`\`

If it fails: <most common failure + specific remedy>

### Step 2 — <next action>

<...>

## Try It Yourself

<A small hands-on exercise the reader runs to cement understanding.
 Must include a concrete starting state and a verifiable ending state.>

## Verify It Worked

\`\`\`bash
<command or check that proves the tutorial's result>
\`\`\`

Expected:

\`\`\`text
<visible success signal>
\`\`\`

## Common Mistakes

- **<mistake 1>** — why it happens, how to recover
- **<mistake 2>** — ...
- **<mistake 3>** — ...

## Next Steps

- Related tutorial: `docs/tutorial-<other>.md`
- Reference: `docs/<relevant-reference>.md`
- Advanced: <pointer to deeper material>
```

Not every section fires every time. Drop sections gracefully per level:

| Section | beginner | intermediate | reference |
| ---- | ---- | ---- | ---- |
| What & Why | full | short | one line |
| Prerequisites | full | short | dropped |
| Core Concepts | full | skip | skip |
| Steps | full with failure hints | condensed | table-only |
| Try It Yourself | full | short | skip |
| Verify It Worked | full | short | skip |
| Common Mistakes | full | full | short table |
| Next Steps | full | full | full |

## Reference

Detailed per-phase instructions. The sequence diagram defines order.

### Resolve level

If the second argument is missing, default to `beginner`. If the argument is none of `beginner`/`intermediate`/`reference`, ask the user to pick.

### Check for existing tutorial

Slug the topic (`hooks` → `hooks`, `update-docs workflow` → `update-docs-workflow`). Check if `docs/tutorial-<slug>.md` exists. If yes, ask the user whether to update (keep structure, refresh content) or create a new version (append `-v2` to the slug).

### Gather real source material

A tutorial must quote real code and real commands — never invent syntax or paraphrase. For each topic:

| Topic type | Where to read |
| ---- | ---- |
| Skill | `skills/<name>/SKILL.md` + companion `.mmd` if any |
| Rule | `rules/<name>.md` |
| Hook | `.claude/settings.json` + `hooks/<name>.sh` |
| Workflow | All SKILL.md of the skills involved + their sequences |
| Concept | Any `docs/*.md` referencing it + the rule(s) that enforce it |
| External | Use `/research <topic>` first, then cite that research file |

Read enough to extract 2-3 real-world snippets per section. Do not paraphrase snippets — copy verbatim and reference their source path.

### Compose tutorial

Apply the template. Fill in each section with real content. When stuck, prefer a table over prose, a concrete example over abstract explanation, and a named file reference over "the file where…".

Beginner-level notes:

- Assume the reader has never run a slash command before. The first step must show them how.
- Define terms on first use, even obvious ones (e.g., "a *rule* is a markdown file in `rules/` that Claude loads automatically").
- Prefer imperative verbs ("Run", "Open", "Edit") over passive.

Intermediate-level notes:

- Skip the "what is Claude Code" intro. Start from "you want to achieve X".
- Show trade-offs where applicable — "approach A saves context but costs X, approach B is simpler but Y".

Reference-level notes:

- Tables over prose. Flags, patterns, return values in grids.
- No exposition. If the reader cares about "why", they open the beginner tutorial.

### Adapt to audience

See the level rubric in the Audience Levels section above. Trim sections per the per-level matrix.

### Save

Write to `docs/tutorial-<slug>.md`. Ensure trailing newline. No `{{placeholders}}` left.

### Verify

Before returning:

- File exists at the expected path
- Frontmatter has `topic`, `level`, `date`, `estimated-time`
- Every referenced file (linked from the tutorial) actually exists
- Every shell command in `Steps` is valid syntax (do not execute — just syntax-scan)
- No bare URLs (`<url>` or `[text](url)` format required by markdown-style rule)

## Output

Summary box with file path and key facts:

```text
╭─ /create-tutorial complete ─────────────────────────────────╮
│                                                             │
│  Topic           <slug>                                     │
│  Level           beginner / intermediate / reference        │
│  File            docs/tutorial-<slug>.md            │
│  Lines           <N>                                        │
│  Est. time       <N> minutes to complete                    │
│  Sources cited   <N> files from .claude/**                  │
│                                                             │
│  Sections:                                                  │
│    • Prerequisites           (<N> items)                    │
│    • Core Concepts           (<N> terms defined)            │
│    • Steps                   (<N> numbered)                 │
│    • Try It Yourself         (exercise included)            │
│    • Verify It Worked        (check command)                │
│    • Common Mistakes         (<N> pitfalls)                 │
│    • Next Steps              (<N> pointers)                 │
│                                                             │
╰─────────────────────────────────────────────────────────────╯
```

## What This Skill Does NOT Do

- Invent commands or syntax — every snippet must come from a real file
- Replace reference docs (`how-to-create-docs.md`, `architecture-overview.mmd`) — those are lookup surface, tutorials are learning surface
- Generate multi-topic tutorials in one run — one topic per file; use cross-references in Next Steps instead
- Target project files — tutorials live in the toolkit `docs/`, even when teaching target-project workflows
- Run the commands it documents — verification is a grep/existence check, not execution
