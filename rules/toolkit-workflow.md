---
description: "Use claude-docs-creator toolkit skills for all .claude/ and CLAUDE.md changes. Do not hand-edit docs without first checking if a skill exists for the task."
paths:
  - ".claude/**"
  - "CLAUDE.md"
---

# Toolkit Workflow — Use Skills, Not Ad-Hoc Edits

## Rule

All changes to `.claude/` files or `CLAUDE.md` in any project with this toolkit attached (via `--add-dir ~/Projects/claude-docs-creator`) MUST go through toolkit skills.

Hand-editing is reserved for:

- Typo fixes in existing content
- Applying `/validate-claude-docs fix` suggestions that the auto-fix could not handle
- Explicit rollback of an earlier skill-driven change
- Content the skill explicitly asks you to fill in (e.g. `<fill in>` placeholders)

For any other change — find the right skill first. If no skill fits, stop and ask the user which workflow to use.

## Why

- **Consistency.** Skills produce the same structure every time. Ad-hoc edits drift projects away from the shared template.
- **Manifest sync.** Skills update `menu`, `skill-scopes`, `two-layer-architecture` automatically. Hand-edits forget these.
- **Validation coverage.** Skills run preflight + post-write validation. Hand-edits bypass both.
- **Drift detection works only on skill-authored content.** `/update-docs` looks for patterns it recognizes.

## Two-Layer Awareness

This rule lives in the **toolkit** (boss), not in target projects. When a target project is attached via `--add-dir`, the toolkit rule activates on any `.claude/**` or `CLAUDE.md` edit regardless of which project it belongs to — toolkit's own files OR the target's.

Target projects stay clean — they do not duplicate or reference toolkit knowledge. If the toolkit is not attached, the rule simply does not load and the user works without guardrails.

## Skill → Task Mapping

| Task | Skill |
| ---- | ---- |
| Initialize `.claude/` from scratch | `/init-project` |
| Add a new rule | `/create-docs rule <name>` |
| Add a new skill | `/create-docs skill <name>` |
| Add a new agent | `/create-docs agent <name>` |
| Edit `.claude/settings.json` | `/create-docs settings` |
| Regenerate `CLAUDE.md` | `/create-docs claude-md` |
| Refresh docs after code changes | `/update-docs <path>` |
| Audit current state | `/validate-claude-docs <path>` |
| Health dashboard | `/status <path>` |
| Generate a diagram | `/create-mermaid <type>` |
| Research a topic | `/research <topic>` |
| Generate a step-by-step runbook | `/create-steps <topic>` |
| Generate an ELI5 tutorial | `/create-tutorial <topic>` |

If the task is not on this table — ask the user. Do not invent a new skill or open a file blindly.

## What NOT to Do

- Do not create new section headings in `CLAUDE.md` on your own — the structure was defined by `/init-project` and is the contract.
- Do not add `paths:` globs without running `/validate-claude-docs` afterwards to verify they match files.
- Do not write new rule files from scratch — use `/create-docs rule`.
- Do not rename or relocate files inside `.claude/` manually — manifests will desync.
- Do not delete rules, skills, or agents without first running `/update-docs <path> report` to see what depends on them.
- Do not copy toolkit meta-rules into target projects — style rules (`markdown-style`, `mermaid-style`, `output-format`) stay in the toolkit repo only.

## Verification

After any session that touched `.claude/` or `CLAUDE.md`:

```text
/validate-claude-docs <path>
```

If the report contains `[ERR]` items or warnings about structure — the rule was likely violated. Revert the hand-edit and redo via the appropriate skill.

## About the Hook Reminder

A `PreToolUse` hook on `Write|Edit` injects a soft reminder via `additionalContext` whenever any file under `.claude/**` or named `CLAUDE.md` is about to be edited. It does NOT block — it only nudges.

Expect the reminder to fire repeatedly during legitimate exception work (e.g. applying a 10-edit `/validate-claude-docs fix` batch). That is by design:

- **Why repeat:** the rule is a safety net for future sessions that may try to hand-edit without remembering the convention. Repetition costs nothing at inference time but preserves the signal for less-aware callers.
- **Why soft (not block):** blocking would prevent the same fix-batch work that Exceptions explicitly allows.
- **When to ignore:** any of the four Exceptions above (typo fix, validate-fix follow-up, rollback, fill-in placeholders). Just keep going.

If the reminder ever fires on files that are NOT toolkit-governed (e.g. `/Users/<user>/.claude/projects/.../memory/*.md` — per-user auto-memory outside any project's `.claude/`), that's a hook glob false positive. Refine the matcher in `hooks/enforce-toolkit-workflow.sh` rather than weakening the rule.
