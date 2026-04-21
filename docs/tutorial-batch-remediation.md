---
topic: batch-remediation
level: intermediate
date: 2026-04-20
estimated-time: 25
---

# Tutorial: Batch-Remediating `/validate-claude-docs` Warnings

You ran `/validate-claude-docs <path>` on a real project. The report came back with 10+ warnings across `CLAUDE.md`, rules, skills, and directory structure. This tutorial walks through the fastest way to close them, in the order that minimizes rework.

Prerequisite — you know what a rule, skill, and scoped `paths:` glob are. If not, start with `tutorial-getting-started.md` first.

## What & Why

Running validate is easy. Closing warnings mid-work causes thrash — you fix one, validate, find two more, fix those, validate, find drift from your fix. The fix: batch everything before touching any file, order by cost × risk, execute top-down, then re-validate once at the end.

End state: clean `/validate-claude-docs` report, `/distill` captures any new toolkit improvements that surfaced, single commit.

## The Recipe

### Group warnings by type

Copy the full validate report into a scratch buffer. Group warnings:

| Group | Examples |
| ---- | ---- |
| Structure moves | non-canonical subdirs (`checklists/`, `templates/`) |
| Size reductions | CLAUDE.md >200 lines, SKILL.md >200 lines |
| Metadata fixes | missing `argument-hint`, empty `description`, kebab-case typos |
| Reference repairs | stale `@path` imports, dead file references |
| Duplication | sections in both CLAUDE.md and a scoped rule |
| False positives | multi-H1 inside fenced code blocks, etc. |

### Order the batches

Execute in this order to minimize rework:

1. **Cheap wins** (2-5 min, zero risk) — add missing frontmatter, trivial renames
2. **Structure moves** (10-20 min, git mv + reference updates) — do BEFORE content edits so references update in one pass
3. **Content slim-down** (20-40 min, highest impact) — CLAUDE.md ↔ scoped rule dedup, skill splits
4. **False-positive review** (5 min) — confirm validator bugs (log to `/distill`, don't edit)

### Execute Batch 1 (cheap wins)

Apply in parallel — these are independent:

- Add `argument-hint: "<description>"` to any skill whose body uses `$ARGUMENTS`
- Fix kebab-case typos in frontmatter (`user_invocable` → `user-invocable`)
- Add trailing newlines to files that lack them

No confirmation needed — all reversible, no structural change.

### Execute Batch 2 (structure moves)

For each non-canonical subdir (e.g. `.claude/checklists/`):

1. Decide destination per content type:
   - Prose `.md` → `docs/<prefix>-<name>.md`
   - Skill-owned code (`.js`, `.css`) → `skills/<owner>/templates/` or `/examples/`
2. `git mv` so history follows the file.
3. Grep for the old path across `.claude/**/*.md` and `CLAUDE.md` — update every reference.
4. `rmdir` the now-empty source dir.

Do all files in one pass before running any edit, so the reference sweep catches everything.

### Execute Batch 3 (content slim-down)

**CLAUDE.md duplication.** For each `[WARN] duplicated section`:

1. Read the scoped rule — confirm it covers the section at equal-or-greater depth.
2. Delete the duplicated section from CLAUDE.md.
3. Replace all deleted sections with one consolidated "Scoped Rules" pointer block (see `docs/how-to-slim-claude-md.md` for the exact template).

**Oversized skills.** If a SKILL.md is >500 lines, it usually has inline flow that should be in a `.mmd`. Split:

1. Extract ordered phases into `sequences/<skill-name>.mmd`.
2. Add `> **Flow:** read sequences/<skill-name>.mmd` at the top of SKILL.md.
3. Rewrite SKILL.md sections as reference material (templates, constraints, tables) — no flow language.

### Execute Batch 4 (false-positive review)

Some warnings are validator bugs, not real problems:

- Multi-H1 often means `# bash comment` inside a ` ```bash ` fenced block. Re-scan with a fence-aware counter before editing.
- `paths:` glob matching zero files may be a deleted module that the rule should also be retired for — ask the user, don't auto-delete.

For each false positive, note it for `/distill` — don't touch the file.

## Try It Yourself

Pick any target project with a mature `.claude/`. Run:

```text
/validate-claude-docs <path>
```

Group the output by the table above. Estimate total batch time. Execute.

Then run:

```text
/validate-claude-docs <path>
```

again. The warning count should drop by 70-90%. Anything remaining is either structural (needs your judgment) or a validator false positive (log for `/distill`).

Finally:

```text
/distill
```

capture any new patterns, gaps, bugs, or user-preference feedback that emerged during the remediation.

## Verify

Success criteria:

- [ ] Re-run of `/validate-claude-docs <path>` shows 0 errors, ≤2 warnings
- [ ] No file in `.claude/` or `CLAUDE.md` is larger than soft-limit tier for its type
- [ ] All references to moved/renamed files resolve (`git grep <old-path>` returns nothing)
- [ ] `/distill` captured ≥1 new finding if the validator missed something

## Common Mistakes

| Mistake | Why it hurts | Fix |
| ---- | ---- | ---- |
| Editing mid-audit | Triggers new drift, validator output becomes inconsistent | Batch all warnings before any edit |
| Deleting before moving refs | Leaves orphan references | Always grep + update before `rmdir` |
| Auto-fixing duplications | Wrong side gets deleted, lose content | Duplicates are structural — decide canonical side manually |
| Skipping final re-validate | Miss regressions introduced by the batch | Always re-run validator after applying |
| Running `/distill` mid-remediation | Proposes fixes for things you're about to fix | Save `/distill` for session end |

## Next Steps

- `docs/how-to-slim-claude-md.md` — the specific recipe for CLAUDE.md duplication
- `docs/tutorial-paths-scoping.md` — if rules have wrong `paths:` scopes after the move
- `.claude/skills/distill/SKILL.md` — what `/distill` captures from a clean-up session
