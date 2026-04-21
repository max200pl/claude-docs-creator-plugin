# How to Slim Down CLAUDE.md via Scoped-Rule Pointers

When `CLAUDE.md` exceeds 200 lines and contains sections that duplicate scoped rules (those with `paths:` frontmatter in `rules/`), replace the duplicated sections with a single pointer list. Typical savings: 30-40% of file size, reclaimed as context on every session.

## When to Apply

Run `/validate-claude-docs <path>` first. The `[WARN] No sections duplicated in scoped rules` line-item gives you the exact list. If it reports 3+ overlapping sections and `CLAUDE.md > 250 lines`, slim-down is the highest-impact single fix.

## Recipe

1. Identify the overlapping sections from `/validate-claude-docs` output.
2. For each pair, read the scoped rule and confirm it covers the section's content at equal-or-greater depth. If not, migrate the missing detail into the rule FIRST.
3. Replace all N duplicated sections in `CLAUDE.md` with one consolidated block:

```markdown
## Scoped Rules

Detailed conventions live in `rules/` and load automatically when Claude edits matching files:

- **<Topic>** (one-line scope) → `rules/<name>.md` — loads on `<glob>`
- **<Topic>** (one-line scope) → `rules/<name>.md` — loads on `<glob>`
- ...
```

4. Keep in `CLAUDE.md`: project goal, stack, build/run commands, project structure tree, naming conventions, build/test shortcuts.
5. Remove from `CLAUDE.md`: anything that is stack-specific detail, layer-specific rules, or workflow-specific procedure — those belong in scoped rules.
6. Re-run `/validate-claude-docs <path>` — the `[WARN]` for duplicated sections should be gone and the size tier should drop to `[OK]`.

## Why This Works

`CLAUDE.md` is loaded into context on EVERY session. Scoped rules load only when Claude touches a file matching their `paths:` glob. Duplicating content in both means paying the token cost unconditionally.

A monorepo with 5 scoped rules and a 300-line CLAUDE.md typically has 80-120 lines of duplication. Moving to pointer style:

- `CLAUDE.md`: 300 → 180 lines (−40%)
- Context per session: −120 lines unconditional savings
- Scoped rules: unchanged (they already carried the canonical content)

## What NOT to Remove

- Anything that must load on every session regardless of file type (naming conventions, response style, build commands)
- Project-wide policies (reuse policy, definition of done) — these aren't stack-specific and need to be visible to all sessions
- High-level orientation (what the project IS) — loading a rule only when editing `res/**/*.css` doesn't help a design discussion

## Real Example

From `sciterjsMacOS` audit (2026-04-20):

| Before | After |
| ---- | ---- |
| `CLAUDE.md` = 269 lines | `CLAUDE.md` = 180 lines |
| `## Sciter Compatibility Rules` (22 lines) | → pointer to `rules/sciter-core.md` |
| `## Sciter CSS Rules` (11 lines) | → pointer to `rules/sciter-css.md` |
| `## FSD Structure` + `## Component Placement Rules` (34 lines) | → pointer to `rules/project-architecture.md` |
| `## Design System` + `### Tokens` (17 lines) | → pointer to `rules/design-system.md` |
| `## Figma MCP Integration` (3 lines, already a pointer) | consolidated into one block |

Net: −89 lines of CLAUDE.md, same scoped rules, no content loss.

## Related

- Rule authoring: `docs/how-to-create-docs.md`
- `paths:` scoping cheatsheet: `docs/tutorial-paths-scoping.md`
- Validator: `/validate-claude-docs` surfaces the overlap list
