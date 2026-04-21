# How To: Structure and Split `docs/`

When a file in `docs/` grows past its size tier, or when the folder starts mixing too many doc types, restructure before the mess compounds. This doc is the practical companion to `rules/docs-folder-structure.md` — the rule states the limits, this doc shows how to apply them.

## Quick Decision Tree

```text
File size tier?
├── [OK]   → do nothing
├── [WARN] → candidate for split, plan now, execute when convenient
└── [ERR]  → MUST split before the next edit

Type match filename prefix?
├── yes → keep prefix, maybe split within type
└── no  → rename first (git mv), then split

Content is CONSTRAINT (must / must not)?
├── yes → promote to rules/ (NOT docs/)
└── no  → stay in docs/, pick the right prefix
```

## Recipe: Split a Large `tutorial-<topic>.md`

A tutorial past 400 lines (`[WARN]`) almost always covers multiple workflows. Split it into a multi-part tutorial folder:

1. Identify natural seams — look for `##` headings that introduce a distinct workflow.
2. `git mkdir -p docs/tutorial-<topic>/`
3. `git mv docs/tutorial-<topic>.md docs/tutorial-<topic>/index.md`
4. Split `index.md` body into parts — each part becomes its own file:

   ```text
   docs/tutorial-<topic>/
   ├── index.md           — overview, prerequisites, links to parts
   ├── part-setup.md      — environment setup
   ├── part-basics.md     — first use
   └── part-advanced.md   — edge cases, patterns
   ```

5. `index.md` shrinks to ~50 lines: one H1, one intro paragraph, a numbered list of parts with one-line summaries.
6. Each part becomes ≤150 lines with its own `Prerequisites`, `Steps`, `Verify` sections.
7. Grep for the old filename: `grep -rn 'tutorial-<topic>.md' .claude/ CLAUDE.md` — update every reference to `tutorial-<topic>/index.md`.

## Recipe: Split a Large `how-to-<topic>.md`

A how-to past 200 lines usually conflates two problems. Split horizontally:

1. Extract each distinct problem → its own file: `how-to-<topic>-<subproblem>.md`
2. Keep the original only if there's a cross-cutting pattern worth summarizing; otherwise delete and update referrers.
3. Do NOT create a `docs/how-to-<topic>/` folder — how-tos are pattern references, they should be peers, not nested.

## Recipe: Split a Large `research-<topic>.md`

Research reports can grow past 600 lines naturally when a topic has multiple sub-surfaces:

1. Create `docs/research-<topic>/` folder.
2. `git mv research-<topic>.md research-<topic>/index.md` — index becomes the overview with source list.
3. Per deep-dive, pull out a sub-topic into `research-<topic>/<sub>.md` (e.g. `research-flow-testing/inspect-ai.md`, `research-flow-testing/golden-traces.md`).
4. `index.md` keeps a 1-sentence summary per sub-file and the consolidated Gaps / Recommendations tables.

Unlike tutorials, research sub-files don't need `part-` prefix — they're named by the tool/topic they research.

## Recipe: Flatten an Over-Nested Tree

If someone created `docs/frontend/ui/buttons/guidelines.md` (3 levels deep):

1. Move to 1 level: `docs/frontend-ui-buttons-guidelines.md` or pick the canonical prefix: `docs/how-to-build-buttons.md`.
2. `rmdir` the now-empty intermediate dirs.
3. If there were 5+ files in one parent dir, keep 2 levels with an `index.md`:

   ```text
   docs/frontend/
   ├── index.md              — lists all frontend docs
   ├── tutorial-setup.md
   ├── how-to-build-button.md
   └── how-to-add-route.md
   ```

Never leave a 3+ level tree. `docs/a/b/c/file.md` is always wrong.

## Recipe: Promote `docs/<x>.md` → `rules/<x>.md`

If a doc file says "MUST / NEVER / always do X" and is actionable by Claude on its own, it's a rule in disguise:

1. Read the file — confirm it's constraint-shaped, not procedure-shaped.
2. Create `rules/<x>.md` with the same content, adding `description:` and `paths:` frontmatter.
3. Remove doc-style prose (intros, narrative, "Next Steps") — rules are terse.
4. `git rm docs/<x>.md` after confirming the rule loads on the right file types.
5. Update `CLAUDE.md` and any skills that linked to the old doc path.

Signs a file belongs in `rules/`, not `docs/`:

- Starts with "## Rule" or "Rule:"
- Contains a "Forbidden" / "Required" list at the top
- Claude should consult it every time a matching file is edited, not only when a human reads it

Signs a file belongs in `docs/`, not `rules/`:

- Starts with "Tutorial:", "How To:", "Research:", "Checklist:"
- Contains a narrative arc ("first... then... finally...")
- Intended for humans to read end-to-end once, not for Claude to consult per-edit

## Recipe: Add a Subdirectory

Before creating a subdir, count files that would share the prefix. If under 5 — stay flat. If 5+ OR the topic demands a master + parts structure:

1. `git mkdir docs/<area>/`
2. Move files: `git mv docs/<area>-*.md docs/<area>/` (strip the `<area>-` prefix from filenames since it's now the dir name).
3. Create `docs/<area>/index.md` — 30-50 lines listing every sibling with a one-line purpose.
4. Grep-update all referrers: `grep -rn 'docs/<area>-' .claude/ CLAUDE.md`.
5. Verify max 2 levels: `find .claude/docs -mindepth 3 -type f` should return empty.

## When to Consolidate Instead of Split

Sometimes the warning is a signal to MERGE, not SPLIT:

- Multiple files with near-identical content — merge into one canonical doc, redirect the others to its path, `git rm` the duplicates.
- A 30-line doc referenced only from one skill — inline it into that skill's SKILL.md and `git rm` the doc.
- A how-to that's just a link list — convert into a `reference-*.md` index file instead.

## Verification After Restructuring

After any split/merge/promote operation:

```bash
# No 3+ level nesting
find .claude/docs -mindepth 3 -type f

# No orphan references
grep -rn '<old-filename>' .claude/ CLAUDE.md

# All files match a known prefix (or are grandfathered)
ls docs/*.md | grep -vE '^(tutorial|how-to|checklist|research|reference|mapping)-'

# Size tiers (run the validator)
/validate-claude-docs .
```

If any command returns unexpected output — finish the cleanup before moving on.

## Related

- `rules/docs-folder-structure.md` — the rule this doc implements
- `docs/how-to-slim-claude-md.md` — same principle for `CLAUDE.md`
- `skills/validate-claude-docs/SKILL.md` — what the validator checks
