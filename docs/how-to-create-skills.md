# How to Create .claude Skills and Agents

> Official docs: <https://code.claude.com/docs/en/claude-directory>

Reference for skills, agents, commands, output styles, and global user-level files.

---

## Skills — Reusable Workflows

**Location:** `skills/<skill-name>/SKILL.md`

Invoked as `/skill-name`. Both you and Claude can invoke skills by default.

```markdown
---
description: "Reviews code changes for security vulnerabilities"
disable-model-invocation: true
argument-hint: "<branch-or-path>"
---

## Diff to review

!`git diff $ARGUMENTS`

Audit the changes above for:

1. Injection vulnerabilities (SQL, XSS, command)
2. Authentication and authorization gaps
3. Hardcoded secrets or credentials

Use checklist.md in this skill directory for the full review checklist.
```

**Frontmatter fields:**

- `description:` — when to trigger this skill (and auto-invocation hint)
- `disable-model-invocation: true` — user-only, Claude never auto-invokes
- `user-invocable: false` — hide from `/` menu, Claude can still invoke
- `argument-hint:` — hint for arguments

**Arguments:** `/deploy staging` passes "staging" as `$ARGUMENTS`. Use `$0`, `$1` for positional access.

**Supporting files:** Place alongside SKILL.md. Claude knows the skill directory path and can read them. For shell commands use `${CLAUDE_SKILL_DIR}`.

---

## Commands (Legacy) — Single-File Prompts

**Location:** `.claude/commands/<name>.md`

Commands and skills are now the same mechanism. For new workflows, use `skills/` instead.

```markdown
---
argument-hint: "<issue-number>"
---

!`gh issue view $ARGUMENTS`

Investigate and fix the issue above.
```

---

## Agents — Specialized Subagents

**Location:** `agents/<agent-name>.md`

Each agent runs in its own context window.

```markdown
---
name: code-reviewer
description: "Reviews code for correctness, security, and maintainability"
tools: Read, Grep, Glob
---

You are a senior code reviewer. Review for:

1. Correctness: logic errors, edge cases, null handling
2. Security: injection, auth bypass, data exposure
3. Maintainability: naming, complexity, duplication

Every finding must include a concrete fix.
```

**Frontmatter fields:**

- `description:` — when to delegate to this agent
- `tools:` — allowed tools (restricts access)
- `model:` — model override (sonnet, opus, haiku)
- `memory:` — persistent memory (`project` = committed, `local` = gitignored, `user` = cross-project in `~/.claude/`)

**Tips:**

- Type `@` and pick an agent from autocomplete to delegate directly
- Agents with `memory:` get a dedicated directory at `.claude/agent-memory/<agent-name>/`

---

## Output Styles

**Location:** `output-styles/<name>.md` (project) or `~/output-styles/<name>.md` (global)

Custom system-prompt sections that adjust how Claude works.

```markdown
---
description: "Explains reasoning and asks you to implement small pieces"
keep-coding-instructions: true
---

After completing each task, add a brief "Why this approach" note.

When a change is under 10 lines, leave a TODO(human) marker instead.
```

Select with `/config` or `outputStyle` in settings. Changes take effect on the next session.

---

## Global Files (`~/`)

| File | Purpose |
| ---- | ------- |
| `~/.claude.json` | App state, UI preferences, personal MCP servers |
| `~/.claude/CLAUDE.md` | Personal preferences across all projects |
| `~/.claude/settings.json` | Default settings for all projects |
| `~/.claude/keybindings.json` | Custom keyboard shortcuts (`/keybindings`) |
| `~/rules/` | User-level rules for every project |
| `~/skills/` | Personal skills for every project |
| `~/.claude/commands/` | Personal commands for every project |
| `~/agents/` | Personal subagents for every project |
| `~/output-styles/` | Personal output styles |
| `~/.claude/projects/<project>/memory/` | Auto memory per project (Claude writes) |
