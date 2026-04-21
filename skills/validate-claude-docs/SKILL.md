---
name: validate-claude-docs
scope: api
description: "Validate a target project's .claude/ directory — check CLAUDE.md, rules, skills, settings for correctness. Runs from toolkit against any project path."
user-invocable: true
argument-hint: "<project-path> [fix]"
---

# Validate .claude Documentation

> Preflight: follow `rules/api-skill-preflight.md` before running any check
> Reference guide: read `docs/how-to-create-docs.md`
> Official docs: <https://code.claude.com/docs/en/claude-directory>

Audit another project's `.claude/` directory and `CLAUDE.md` — run from the toolkit repo against a target project path (boss-mode, same as `/init-project`).

## Mirror of `/create-docs`

This skill is the **inverse** of `/create-docs`. Every structural guarantee that `/create-docs` produces for a file type must have a matching check here. If `/create-docs` adds a field, this skill verifies it; if `/create-docs` scaffolds a companion file, this skill checks the companion exists. Keep the two skills in sync.

| `/create-docs` produces | This skill verifies |
| ---- | ---- |
| Rule with `paths:` + `description:` | Rule has both in frontmatter, globs match |
| Skill dir with `SKILL.md` + `description` | SKILL.md exists, frontmatter valid |
| Skill with ordered phases + Flow reference | Companion `.mmd` exists in `sequences/` |
| Agent with `description` + `model` + `tools` | All three present, values valid |
| Settings with `permissions.allow/deny` + hooks | JSON valid, hook format current |
| CLAUDE.md under 200 lines, no placeholders | Same size + placeholder checks |
| Per-module `CLAUDE.md` under 60 lines | Same size check per sub-area |

## Usage

```text
/validate-claude-docs <project-path>         # report only
/validate-claude-docs <project-path> fix     # report + auto-fix what's fixable
```

**Examples:**

- `/validate-claude-docs ~/Projects/GameBooster`
- `/validate-claude-docs ~/Projects/GameBooster fix`
- `/validate-claude-docs .` — validate the current directory (when toolkit dev wants to self-check)

If `<project-path>` is omitted, ask the user for it. Do not default to the toolkit's own cwd — this skill is about OTHER projects.

## Mode

The second argument controls behavior:

- no second arg → **report only**
- `fix` → **report + auto-fix** what's trivially fixable

Pass the mode into the preflight's confirmation box so the user sees it.

## Validation Checklist

### CLAUDE.md

- [ ] Exists at `$TARGET/CLAUDE.md` or `$TARGET/.claude/CLAUDE.md` (not both)
- [ ] Size tier — see Per-Type Size Table
- [ ] Has at least one heading for build/test commands
- [ ] No `{{placeholders}}` left from template — all filled in
- [ ] Referenced file paths actually exist in `$TARGET`
- [ ] `@path` imports (if used) point to real files
- [ ] No duplicated info from git history or code comments
- [ ] **No sections duplicated in scoped rules** — if a `rules/<X>.md` has `paths:` frontmatter and a similar heading exists in CLAUDE.md, the CLAUDE.md version is dead weight (loads always) and should be moved into the scoped rule. Flag as `[WARN]` with the overlapping heading names.
- [ ] **Per-module CLAUDE.md** (`<area>/CLAUDE.md` for monorepos) — ≤60 lines `[OK]`, 61-100 `[WARN]`, >100 `[ERR]`

### Rules (`$TARGET/rules/`)

- [ ] Each rule file has valid YAML frontmatter
- [ ] `description:` field present and non-empty (required by `/create-docs`)
- [ ] Rules use official Claude Code field names (`alwaysApply`, `paths`, `description`)
- [ ] `paths:` globs match actual files in `$TARGET` (run Glob with cwd=`$TARGET`)
- [ ] Size tier — see Per-Type Size Table (rules split at soft)
- [ ] No rules duplicating content from CLAUDE.md
- [ ] Conditional rules use `paths:` to save context tokens
- [ ] No empty or placeholder rule files (under 20 lines with no headings → `[WARN]`)
- [ ] No toolkit meta-rules leaked in (no-step-numbers, menu-sync, skill-scopes, two-layer-architecture, output-format, no-project-context, sequence-diagram-source-of-truth, markdown-style, mermaid-style, docs-english-only, api-skill-preflight, toolkit-workflow, docs-folder-structure)

### Skills (`$TARGET/skills/`)

- [ ] Each skill has `SKILL.md` in its own directory
- [ ] SKILL.md has valid frontmatter (`description` required)
- [ ] Skill frontmatter uses kebab-case: `user-invocable`, `argument-hint`, `disable-model-invocation`
- [ ] Size tier — see Per-Type Size Table (if over, split phases into `.mmd` + reference files)
- [ ] Supporting files referenced in SKILL.md actually exist in the skill directory
- [ ] Description is specific enough for auto-triggering (≥40 chars, names at least one trigger phrase or condition)
- [ ] `argument-hint` present if the skill expects arguments
- [ ] **Flow reference:** if SKILL.md contains ordered phases or `> **Flow:** read ...` marker, the referenced `.mmd` exists in `$TARGET/sequences/`. Missing `.mmd` → `[ERR]`.
- [ ] Section headings in SKILL.md roughly match `note` labels in the companion `.mmd` (drift warning only)
- [ ] No toolkit skills copied in (init-project, create-docs, update-docs, create-mermaid, research, sleep, validate-claude-docs, menu, status, distill, create-steps, create-tutorial)

### Docs (`$TARGET/docs/`)

Reference prose (tutorials, how-tos, checklists, research, mappings). Not auto-loaded — consumed by skills via `Read`, linked from other docs, or surfaced by `/menu`. See `rules/docs-folder-structure.md` for the authoring rules.

- [ ] **Filename prefix** — every file starts with one of: `tutorial-`, `how-to-`, `checklist-`, `research-`, `reference-`, `mapping-`, OR is a grandfathered meta-doc (`milestones.md`, `testing-checklist.md`, `two-claude-workflow.md`). Other names → `[WARN]` "rename to match prefix or move out of docs/".
- [ ] **Size tier per type** — apply from the table below. Soft = `[OK]`, Warn = `[WARN]`, Hard = `[ERR]`.

  | Prefix | Soft ≤ | Warn ≤ | Hard > |
  | ---- | ---- | ---- | ---- |
  | `tutorial-` | 400 | 600 | 600 |
  | `how-to-` | 200 | 350 | 350 |
  | `checklist-` | 150 | 250 | 250 |
  | `research-` | 600 | 1000 | 1000 |
  | `reference-` | 300 | 500 | 500 |
  | `mapping-` | 200 | 400 | 400 |
  | grandfathered | 400 | 600 | 600 |

- [ ] **Nesting depth** — `docs/<file>.md` (1 level) or `docs/<area>/<file>.md` (2 levels) only. `find .claude/docs -mindepth 3 -type f` must be empty. Any 3+ level path → `[ERR]`.
- [ ] **Subdir has `index.md`** — every `docs/<area>/` subdirectory must contain `index.md` that lists siblings with one-line summaries. Missing index → `[ERR]`.
- [ ] **Subdir has 5+ related files OR multi-part tutorial/research** — a `docs/<area>/` with only 1-2 files is over-nested → `[WARN]` "flatten back".
- [ ] **Rule-shaped content in docs/** — flag files that start with "## Rule", "Rule:", or have a top-level "Forbidden / Required" pair. These likely belong in `rules/`, not `docs/`. `[WARN]` "promote to scoped rule".
- [ ] **Embedded Mermaid in docs/** — grep for ` ```mermaid ` fences. For each, count lines of Mermaid. If any block is ≥50 lines → `[WARN]` "extract to `sequences/<name>.mmd`". Small diagrams (<50 lines) can stay inline. A `.mmd` file in `docs/` instead of `sequences/` is `[ERR]`.
- [ ] **Cross-references use relative links** — `[text](./sibling.md)`, not absolute paths, not anchor-fragment links between files.
- [ ] **Broken cross-refs** — every `[text](./<path>.md)` in `docs/**` must resolve to an existing file.

### Cross-layer Content Placement

Each content type has one canonical home. Anywhere else = flag. Detection heuristic is the file's content shape (not its current path).

| Content shape | Canonical home | Elsewhere |
| ---- | ---- | ---- |
| `.mmd` file | `sequences/` | `[ERR]` move |
| Skill-shaped (`description` + phases) | `skills/<name>/SKILL.md` | `[ERR]` move |
| Agent-shaped (`model` / `tools`) | `agents/<name>.md` | `[ERR]` move |
| Rule-shaped (`## Rule`, Forbidden/Required) | `rules/<name>.md` + `paths:` | `[WARN]` promote |
| File-type convention in CLAUDE.md with no matching rule | `rules/<topic>.md` | `[WARN]` generate + slim |

### Sequences (`$TARGET/sequences/`)

- [ ] Each `.mmd` in `sequences/` has a SKILL.md that references it (no orphan diagrams → `[WARN]`)
- [ ] Each `.mmd` starts with `%%{init: {'theme': 'neutral'}}%%`
- [ ] `.mmd` files contain raw Mermaid (no ` ```mermaid ` fences)
- [ ] No `rect rgb(...)` / hardcoded colors
- [ ] No inline styles (`style nodeId fill:#...`)
- [ ] No `direction` inside subgraphs
- [ ] No nested subgraphs deeper than 2 levels
- [ ] No `Step N —` prefixes in `note over` labels

### Agents (`$TARGET/agents/`)

- [ ] Each agent `.md` file has valid frontmatter (`description` required)
- [ ] `model:` is valid (sonnet, opus, haiku) if specified
- [ ] `tools:` present and restricts access appropriately (comma-separated string: `Read, Grep, Glob`). Missing `tools:` → `[WARN]` (agent gets everything)
- [ ] `memory:` if present is one of: `project`, `local`, `user`
- [ ] Description clearly defines when to delegate (≥60 chars, contains trigger phrases)
- [ ] Size tier — see Per-Type Size Table

### Settings (`$TARGET/.claude/settings.json`)

- [ ] Valid JSON syntax
- [ ] `permissions.allow` patterns are not overly broad (no `Bash(*)`)
- [ ] `permissions.deny` blocks dangerous operations (`rm -rf`, `git push --force`)
- [ ] Hooks use current format: `PostToolUse` with `matcher` and `hooks` array
- [ ] No secrets or tokens in committed settings (should be in `.local.json` instead)

### Structure

- [ ] **Known subdirs:** `rules`, `skills`, `docs`, `agents`, `sequences`, `memory`, `agent-memory`, `output-styles`, `hooks`, `commands`, `plugins` — accept silently.
- [ ] **Unknown subdirs:** before flagging as `[WARN]`, verify against the official docs. Do NOT hardcode-reject — Claude Code adds new top-level `.claude/` folders (e.g. `output-styles`, `hooks`, `commands`, `plugins` were all added over time). Procedure:
  1. Collect all subdirs under `$TARGET/.claude/` that are not in the Known list above.
  2. For each unknown subdir, WebFetch `https://docs.claude.com/en/docs/claude-code/` and sibling pages (`.../slash-commands`, `.../hooks`, `.../plugins`, `.../settings`, `.../sub-agents`, `.../memory`, `.../output-styles`, `.../skills`). Search for the folder name (case-insensitive).
  3. If the name appears in official docs as a `.claude/<name>/` path → classify as `[INFO]` "officially supported" and update the Known list for the next run.
  4. If NOT found in official docs → `[WARN]` "non-canonical — consider consolidating into `docs/` or naming convention matches a supported folder."
  5. Cache findings in-session so each unknown name is checked only once per run.
- [ ] `$TARGET/.gitignore` includes: `CLAUDE.local.md`, `.claude/settings.local.json`, `.claude/agent-memory-local/`
- [ ] `.mmd` files contain raw Mermaid (no ` ```mermaid ` fences)
- [ ] `.md` files with Mermaid use fenced blocks
- [ ] Every `.md`/`.mmd` ends with a single trailing newline
- [ ] Heading hierarchy: no level skips (`#` → `###`), one `#` per file. **Count ONLY headings outside fenced code blocks** — `# foo` inside ` ```bash ` / ` ```sh ` / ` ```python ` is a comment, not a heading. Before reporting multi-H1, re-scan each file with a fence-aware counter (toggle `in_fence` on every ` ``` ` line).
- [ ] **Ordered lists numbered sequentially** — `1.`, `2.`, `3.`, not `1. 1. 1.` (markdownlint MD029 "ordered" style). Flag any ordered-list block with two or more consecutive `1. ` items.
- [ ] If target project has `.markdownlint.json`: `MD029` should be `"ordered"` or `"one_or_ordered"`, not `"one"` alone.

### Per-Type Size Table

Soft = nudge, Hard = must split. Mirror of the limits `/create-docs` respects when scaffolding.

| File | Soft (`[OK]` ≤) | Warn (`[WARN]` ≤) | Hard (`[ERR]` >) |
| ---- | ---- | ---- | ---- |
| `CLAUDE.md` (root) | 200 | 300 | 300 |
| `<area>/CLAUDE.md` (per-module) | 60 | 100 | 100 |
| `rules/*.md` | 300 | 500 | 500 |
| `skills/*/SKILL.md` | 200 | 500 | 500 |
| `agents/*.md` | 250 | 400 | 400 |
| `docs/*.md` | 400 | 600 | 600 |
| `sequences/*.mmd` | 150 | 300 | 300 |

## Output Format

Box header with the target, then line-items, then summary.

```text
╭─ Validate .claude/ ─────────────────────────────────────────╮
│                                                             │
│  Target       ~/Projects/GameBooster                        │
│  Mode         report / fix                                  │
│                                                             │
╰─────────────────────────────────────────────────────────────╯

[OK]   CLAUDE.md — 85 lines, no placeholders remaining
[WARN] rules/code-style.md — no paths: frontmatter (loads every session — intentional?)
[ERR]  skills/deploy/SKILL.md — references checklist.md, file doesn't exist
[FIX]  CLAUDE.md:42 — removed stale reference to deleted module
[FIX]  rules/api.md — added trailing newline
───
N files scanned, F fixes applied, W warnings, E errors
```

## Fix mode

When the second argument is `fix`, auto-resolve what's trivially fixable:

- Add missing trailing newlines
- Remove `Step N` prefixes from headings (write-only files already in target)
- Fix kebab-case frontmatter typos (`user_invocable` → `user-invocable`)
- Remove stale file references where the referenced file doesn't exist
- Renumber ordered lists sequentially (`1. 1. 1.` → `1. 2. 3.`) for any block with two or more consecutive `1. ` items
- **Add `argument-hint:` frontmatter** to any skill whose SKILL.md body uses `$ARGUMENTS` but frontmatter has no `argument-hint:`. Derive the hint from the argument's use context — if ambiguous, leave as `<arg>` placeholder and `[WARN]` for manual rename.
- **Consolidate non-canonical subdirs (interactive)** — for each `.claude/<non-canonical>/` detected (not in known list and not found in official docs), propose the move plan and ask before executing:

  ```text
  [WARN] .claude/checklists/ — non-canonical
    Propose:
      - Move .claude/checklists/component-done.md → docs/checklist-component-done.md
      - Grep-update 3 references across .claude/ and CLAUDE.md
      - rmdir .claude/checklists
    Apply? (y/n/skip)
  ```

  Classification heuristics:
  - Prose `.md` content → `docs/<prefix>-<name>.md` (e.g. `checklists/x.md` → `docs/checklist-x.md`)
  - Code files (`.js`, `.css`, `.ts`) referenced by ONE skill → `skills/<owner>/templates/` or `/examples/`
  - Multiple-owner code files → `docs/` with directory preserved
  - Use `git mv` so history stays intact

Never auto-fix:

- Anything requiring semantic understanding (rule content, module descriptions)
- `paths:` globs — may need human judgment
- Deletion of files (always ask)
- CLAUDE.md ↔ scoped-rule duplications (structural, needs a human to decide which side is canonical) — but point the user at `docs/how-to-slim-claude-md.md` for the recipe
