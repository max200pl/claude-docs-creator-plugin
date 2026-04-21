---
topic: getting-started
level: beginner
date: 2026-04-20
estimated-time: 30
---

# Tutorial: Getting Started With `claude-docs-creator`

## What & Why

By the end of this tutorial you will have Claude-generated documentation for one of your own projects — `CLAUDE.md` with accurate build commands, a `rules/` tree with path-scoped rules, and a workflow for keeping those docs in sync as your code changes.

Why bother: Claude Code works dramatically better on a project that has good `CLAUDE.md` + rules. Without them, Claude reads random files trying to guess your conventions. With them, it follows documented patterns and saves 40-70% of the context window on every session.

The toolkit automates the tedious parts of writing that documentation.

## Prerequisites

- Claude Code installed (`claude --version` should work)
- A git repository you actually work on — not a toy — that is at least a few hundred lines of real code
- The toolkit cloned somewhere: `git clone <toolkit-repo> ~/Projects/claude-docs-creator`
- `jq` available on your shell (the toolkit's hooks use it): `brew install jq` on macOS, `apt install jq` on Debian/Ubuntu

## Core Concepts

Five ideas that recur through the rest of this tutorial.

- **Skill** — a markdown file at `skills/<name>/SKILL.md` that defines an invokable slash command. Example: typing `/init-project` triggers the `init-project` skill. Think of skills as the toolkit's "commands".
- **Rule** — a markdown file at `rules/<name>.md` that Claude loads into its context automatically. Two flavors: global (always loaded) and path-scoped (loads only when you edit files matching a glob).
- **`paths:` frontmatter** — the YAML header at the top of a rule file that declares when to load it. Example: `paths: ["src/**/*.py"]` means "load this rule only when touching Python files under `src/`". This is how the toolkit saves context.
- **Scope** — skills have a `scope:` field: `api` (runs on your projects), `shared` (both), `internal` (toolkit-only). Only `api` and `shared` skills auto-trigger outside the toolkit.
- **Two-layer architecture** — the toolkit *lives in one repo*, your projects *consume it*. The toolkit is never copied into your projects; it is attached via `--plugin-dir`.

## Steps

### Step 1 — Verify the toolkit loaded

Action:

```bash
cd ~/Projects/your-project
claude --plugin-dir ~/Projects/claude-docs-creator
```

Inside the Claude Code session, type:

```text
/menu
```

Expected output: a table of available commands grouped by scope (API / Shared / Internal), a short status summary, and a suggested next action.

If it fails: `/menu` not recognized usually means `--plugin-dir` did not pick up the toolkit path. Double-check the path exists; try an absolute path.

### Step 2 — Initialize `.claude/` for your project

Action:

```text
/init-project
```

The skill runs as a wizard. It will:

1. Scan your repo's root for build system markers (`package.json`, `go.mod`, `Cargo.toml`, etc.)
2. Ask you to confirm the detected stack
3. Discover modules (top-level source directories)
4. Create `.claude/`, `CLAUDE.md`, `.claude/settings.json`, and per-module `CLAUDE.md` files
5. Report a summary

Expected output:

```text
╭─ /init-project Complete ────────────────────────────────────╮
│  Type         single-stack                                  │
│  Stack        TypeScript + Next.js                          │
│  CLAUDE.md    root: 87 lines                                │
│  Modules      3 module CLAUDE.md (1 skipped as trivial)     │
│  Settings     ✓  configured                                 │
╰─────────────────────────────────────────────────────────────╯
```

If it fails: the most common error is the skill asking a question you skipped. Scroll up — the wizard pauses at detection checkpoints and needs your "confirm" or "correct" before moving on.

### Step 3 — Look at what got created

Action: open the new files in your editor.

```bash
ls .claude/
cat CLAUDE.md | head -40
```

You should see: `CLAUDE.md` at the project root, a `.claude/` directory with `rules/`, `docs/`, `skills/`, `settings.json`, and per-module `CLAUDE.md` inside each non-trivial module directory.

Key check: open `CLAUDE.md` and verify the build commands are real. Try the build command by pasting it into a terminal. If the command works, the documentation is accurate. If not, edit it now — accuracy matters more than completeness.

### Step 4 — Add your first rule

`/init-project` deliberately does not create rules — rules require judgment about what patterns matter. Add one now.

Action:

```text
/create-docs rule code-style
```

The skill will ask what the rule covers. For a first rule, pick something concrete: naming conventions, import order, error handling — whatever your codebase already follows that Claude should follow too.

The skill will ask which files the rule applies to. Give it a glob — `src/**/*.ts` for a TypeScript project, `**/*.py` for Python, etc. This becomes the rule's `paths:` frontmatter.

Expected output:

```text
[CREATED] rules/code-style.md — conditional rule for src/**/*.ts
[STACK]   Detected: TypeScript + Next.js
```

If it fails: the skill will not create a rule whose `paths:` glob matches zero files. Fix the glob — run `ls src/**/*.ts` in your shell first to confirm it has matches.

### Step 5 — Audit what you have

Action:

```text
/validate-claude-docs .
```

The `.` argument points at the current project. The skill runs a structured audit — checks frontmatter validity, file references, `paths:` glob coverage, line counts, placeholder residues.

Expected output:

```text
[OK]   CLAUDE.md — 87 lines, no placeholders remaining
[OK]   rules/code-style.md — paths: matches 124 files
[WARN] rules/code-style.md — no description in frontmatter
───
4 files scanned, 0 fixes applied, 1 warning, 0 errors
```

If it fails with errors (not warnings): the skill will name the file. Open it and fix.

### Step 6 — Run a dashboard

Action:

```text
/status .
```

Expected output: a visual dashboard with doc stats, rule coverage, staleness by git history, and a list of issues.

Use this whenever you want a quick health check — no edits, just a view.

### Step 7 — Make a code change, then refresh the docs

This is the long-term workflow — write code, then keep the docs honest.

Action: make a real change in your codebase. Add a new module, rename a directory, or change the build command. Then:

```text
/update-docs . interactive
```

The skill:

1. Delegates to `/status` to inventory the current state
2. Delegates to `/validate-claude-docs fix` to catch trivial issues
3. Compares the code to the docs and flags drift (new modules, broken `paths:` globs, outdated build commands)
4. Asks you per-item what to apply

Expected output: a plan box with items labeled `[safe]`, `[review]`, or `[destructive]`. You pick which to apply.

If it fails: the skill will refuse to run if `.claude/` is missing. In that case, go back to Step 2.

### Step 8 — Commit

Action:

```bash
git add CLAUDE.md .claude/
git commit -m "docs: initial Claude Code documentation"
```

The generated files are meant to be committed. They belong to the team, not to you personally.

Exception: `CLAUDE.local.md` and `.claude/settings.local.json` are for personal overrides — the toolkit adds them to `.gitignore` automatically.

## Try It Yourself

Goal: go from nothing to a working toolkit setup on a fresh throwaway repo.

Starting state: an empty git repo you can mess with — `mkdir ~/tmp/tutorial && cd ~/tmp/tutorial && git init && echo 'print("hello")' > main.py && git add . && git commit -m 'init'`.

Do this:

1. Attach the toolkit — `claude --plugin-dir ~/Projects/claude-docs-creator` from inside the repo
2. Run `/init-project`
3. Answer the wizard's questions — pick Python as the stack when asked
4. Run `/validate-claude-docs .` and fix any errors
5. Add a single rule about naming conventions for Python files with `/create-docs rule naming`
6. Make a small change — add a second `.py` file — and run `/update-docs . report`
7. Read the drift report

Ending state: `CLAUDE.md` exists, one rule under `rules/`, drift report shows the new file was noticed.

Time to complete: about 10 minutes.

## Verify It Worked

After the exercise, run this check from your shell:

```bash
ls CLAUDE.md rules/*.md
cat rules/naming.md | head -8
grep "^paths:" rules/naming.md
```

Expected:

```text
CLAUDE.md  rules/naming.md
---
description: "Python naming conventions..."
paths:
  - "**/*.py"
---
# Naming Conventions
paths:
```

If any line is missing or empty, the rule did not land correctly. Re-run `/create-docs rule naming` and verify the wizard completed.

## Common Mistakes

- **Running skills from inside the toolkit repo when you meant your project.** The toolkit's own `.claude/` is not for experimentation. Always `cd` into a real target project first, then attach the toolkit with `--plugin-dir`.
- **Expecting `/init-project` to create rules.** It does not. Rules require you to identify patterns worth documenting, which the skill cannot do for you. Use `/create-docs rule` afterwards.
- **Adding a `paths:` glob that matches zero files.** Claude will load the rule but it is wasted context. `/validate-claude-docs` flags this. Run it after every `/create-docs rule`.
- **Editing `CLAUDE.md` in the toolkit repo expecting changes in your project.** They are two different layers. Your project has its own `CLAUDE.md`.
- **Forgetting to commit `.claude/`.** The docs are team-wide by design — `.claude/settings.local.json` is gitignored but the rest is not. Your teammates benefit only if you push.
- **Skipping `--plugin-dir` and wondering why slash commands do not auto-trigger.** Without it, Claude Code sees only your project's `.claude/` (which initially does not have the API skills). Always attach the toolkit for API skills to be available.

## Next Steps

- **Reference** — `docs/how-to-create-docs.md` documents the full taxonomy of `.claude/` files, when to pick each, and the one-page quick reference.
- **Reference** — `.claude/rules/two-layer-architecture.md` (in the toolkit source repo) explains why the toolkit and your projects stay separate.
- **Workflow tutorial (future)** — `docs/tutorial-update-docs-workflow.md` will walk through the full drift-and-refresh cycle for a project in active development.
- **Advanced (future)** — `docs/tutorial-hooks.md` covers the automation layer: PostToolUse checks, PreCompact reminders, status line.
- **For toolkit contributors** — `.claude/docs/milestones.md` (toolkit source) shows the roadmap (M2-M7) and what is coming next.
