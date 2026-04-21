---
description: "Preflight steps every api-skill runs before touching a target project"
---

# API Skill Preflight

## Rule

Every skill with `scope: api` that takes a `<project-path>` argument MUST reference this rule at the top instead of hardcoding a "steps" block. The preflight is generated dynamically at runtime from the invoking skill's context (skill name, argument-hint, what checks follow).

## Why

- Single source of truth — when preflight logic changes, update one file
- New api-skills don't copy/paste a stale block
- Steps adapt to the invoking skill (its own name, its own arg signature)

## How to reference

At the top of every api-skill SKILL.md:

```markdown
> Preflight: follow `rules/api-skill-preflight.md` before running any check
```

Do NOT copy the step content into the SKILL.md.

## The Preflight Sequence

When an api-skill starts, Claude walks through these steps IN ORDER. Each step has a failure hint — if a step fails, print the hint and STOP.

Throughout: substitute `<SKILL>` with the invoking skill's name (`/validate-claude-docs`, `/status`, etc.) and `<PROJECT-PATH>` with the argument the user passed.

### Parse and resolve path

- Missing argument? Ask the user: `"Which project should /<SKILL> run against? Pass an absolute path or ~/..."`
- Expand `~` → `$HOME`, resolve to absolute path
- Echo back: `Target: <resolved>`

### Check session access

Two-layer check, because Bash and Read/Glob/Grep may have different sandboxing:

1. **Bash layer** — try `ls "<resolved>"`. If it fails with permission denied → fully outside sandbox, STOP.
2. **Read layer** — try Read or Glob on one known file (e.g. `<resolved>/CLAUDE.md` or `<resolved>/.claude/`). If it returns "No files found" for something Bash just listed, or the Read is rejected — Read/Glob is sandboxed even though Bash reaches it.

If either layer fails, print the environment-aware hint:

```text
⚠  <resolved> is not in the current session's working directories.

   Add it depending on how you run Claude Code:

   • CLI:
       /add-dir <resolved>

   • VSCode / JetBrains (IDE extension):
       1. File → Add Folder to Workspace...
       2. Navigate to and select: <resolved>
       3. Click "Add"
       (or restart Claude Code with the folder already open)

   Then re-run:

     /<SKILL> <resolved> [remaining args]
```

STOP. Wait for the user.

**Fallback:** if the user can't add the dir (e.g. `/add-dir` blocked in their IDE and they can't restart), the invoking skill MAY fall back to Bash `cat` / `find` / `rg` for reads on `<resolved>`. Note this in the confirmation box as `Mode: bash-fallback`. Writes / edits still require proper sandbox access.

### Path exists and is a directory

If not:

```text
✗  Target path not found or not a directory: <resolved>
   Check spelling or pass an absolute path.
```

STOP.

### Target has `.claude/`

If `<resolved>/.claude/` is missing:

```text
✗  <resolved> has no .claude/ directory yet.
   Run /init-project <resolved> first.
```

STOP.

### Confirmation box

Print a box naming the target and the mode (from the invoking skill's args), then proceed.

```text
╭─ /<SKILL> ──────────────────────────────────────────────────╮
│  Target       <resolved>                                    │
│  Mode         <report / fix / dashboard / ...>              │
╰─────────────────────────────────────────────────────────────╯
```

From this point `$TARGET = <resolved>`. Every Glob / Read / Grep / Bash path in the invoking skill's checks MUST be rooted at `$TARGET`.

## What NOT to put in this preflight

- Anything skill-specific (actual validation rules, dashboard formulas, etc.) — those stay in the invoking SKILL.md
- Output formatting of the final report — that's the invoking skill's concern
- Permission logic or tool whitelisting — that's in `.claude/settings.json`
