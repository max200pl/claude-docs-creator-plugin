# Reference: `/update-docs` Drift Catalog

Full catalogue of drift kinds detected by `/update-docs`. The SKILL.md keeps a short 2-column map; this doc carries the detection logic and refresh target per kind.

## Catalogue

### `stack`

- **Detect:** re-run `/init-project` Pass 1 + Pass 2 stack detection.
- **Refresh:** Build & Run section in `CLAUDE.md`.

### `modules`

- **Detect:** re-discover modules (`src/*/`, `packages/*/`, solution files, workspace config).
- **Refresh:** new module `CLAUDE.md` generated; orphan module `CLAUDE.md` proposed for deletion.

### `rule-paths`

- **Detect:** Glob each rule's `paths:` globs against the current tree. Zero matches = stale.
- **Refresh:** rule frontmatter rewrite (user confirms the new glob).

### `directory-tree`

- **Detect:** compare top-level dirs with `CLAUDE.md` "Project Structure" section.
- **Refresh:** rewrite the Project Structure block with `ls` output (tree depth 2).

### `build-commands`

- **Detect:** compare Build & Run entries with current `package.json` scripts / `Makefile` / CI definitions.
- **Refresh:** Build & Run section updates.

### `path-imports`

- **Detect:** check each `@path` referenced in `CLAUDE.md` exists.
- **Refresh:** remove dead imports; keep note in skipped-for-review if the file was renamed.

### `non-canonical-subdirs`

- **Detect:** `ls .claude/*/` — compare against known canonical list (`rules`, `skills`, `docs`, `agents`, `sequences`, `memory`, `agent-memory`, `output-styles`, `hooks`, `commands`, `plugins`). For unknowns, WebFetch official docs before flagging.
- **Refresh:** move plan — prose → `docs/<prefix>-<name>.md`; skill-internal code → `skills/<owner>/templates/` or `/examples/`.

### `claude-md-rule-dup`

- **Detect:** for each `rules/*.md` with `paths:`, compare its headings against `CLAUDE.md` H2/H3 list. Matches = duplicated.
- **Refresh:** not auto-applied — point user at `docs/how-to-slim-claude-md.md` for the recipe.

### `mermaid-in-docs`

- **Detect:** grep `docs/**/*.md` for ` ```mermaid ` fences; count lines per block. Any block ≥50 lines = extract candidate.
- **Refresh:** write `sequences/<name>.mmd` (with `%%{init: {'theme': 'neutral'}}%%` header), replace the embed with a pointer line in the source doc.

### `rule-shaped-in-docs`

- **Detect:** `.md` files under `docs/` starting with "## Rule", "Rule:", or containing top-level "Forbidden / Required" pair.
- **Refresh:** promote to `rules/<name>.md` via `/create-docs rule`; add `paths:` if applicable; grep-update all referrers; delete source doc last.

### `claude-md-section-without-rule`

- **Detect:** `CLAUDE.md` sections that describe file-type conventions (e.g. "Sciter CSS Rules", "API Conventions") with no scoped rule carrying that topic.
- **Refresh:** generate `rules/<topic>.md` via `/create-docs rule`, then apply the slim-down recipe to dedupe `CLAUDE.md`.

### `mermaid-in-rules-or-agents`

- **Detect:** `.md` under `rules/` or `agents/` with ` ```mermaid ` sequence/flowchart blocks ≥30 lines.
- **Refresh:** extract to `sequences/<name>.mmd`, replace block with pointer.

### `skill-without-mmd`

- **Detect:** `SKILL.md` contains "Step N", "Phase N" prose AND no `> **Flow:** read sequences/...` marker.
- **Refresh:** generate `.mmd` via `/create-mermaid sequence`, add Flow marker at the top of SKILL.md.

### `misplaced-by-content`

- **Detect:** content type mismatches directory — e.g. `.mmd` outside `sequences/`, skill-shaped doc outside `skills/`, agent-shaped doc outside `agents/`.
- **Refresh:** `git mv` to canonical home; grep-update every reference.

## Related

- SKILL.md: `skills/update-docs/SKILL.md`
- Apply phase mechanics: `docs/reference-drift-repairs.md`
- CLAUDE.md slim recipe: `docs/how-to-slim-claude-md.md`
- Docs structure rule: `rules/docs-folder-structure.md`
