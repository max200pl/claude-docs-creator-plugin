# Reference: `/update-docs` Apply-Phase Mechanics

Order and mechanics for applying approved drift repairs. SKILL.md lists the ordered steps; this doc carries the per-step procedure, verification, and rollback rules.

## Order (least-destructive first)

1. `@path` import repairs
2. `CLAUDE.md` Build & Run / Project Structure refresh
3. New module `CLAUDE.md` generation
4. Rule `paths:` updates
5. Content placement repairs
6. Deletions (explicit approval required)

## Per-Step Procedure

### 1. `@path` import repairs

For each dead `@path` in `CLAUDE.md`:

- If the target file was renamed — grep the repo for the new name, propose the rewrite.
- If the target file was deleted — remove the `@path` line; flag for user review if surrounding prose still references it.
- Verify: re-read `CLAUDE.md`, confirm every `@path` resolves.

### 2. Build & Run / Project Structure refresh

- Read current `package.json` scripts, `Makefile` targets, CI config. Diff against Build & Run section.
- For Project Structure: run `ls` at 2 levels, update the tree. Preserve user comments on lines.
- Never touch naming conventions, reuse policy, or handwritten narrative — those are user content.

### 3. New module `CLAUDE.md` generation

- Follow `/init-project` module-creation logic, scoped to the new modules only.
- Never overwrite a module `CLAUDE.md` with handwritten `Patterns` / `Anti-patterns` / `Rules` sections — that's user content.
- For an existing module whose file count drifted: refresh only the header and Dependencies section.

### 4. Rule `paths:` updates

- Present the proposed glob with a match count preview: `rules/api.md: "src/api/**/*.py" → 14 files`.
- User confirms before write.
- If the new glob matches 0 files, STOP — this usually means the rule should be deleted, not re-scoped.

### 5. Content placement repairs

One atomic move per drift item. Verification after each.

#### 5a. Extract embedded Mermaid (`.md` → `.mmd` in `sequences/`)

- Write the `.mmd` first with `%%{init: {'theme': 'neutral'}}%%` header.
- Replace the embed in the source file with a pointer: `See sequences/<name>.mmd`.
- Verify: source file parses, `.mmd` has valid Mermaid syntax.

#### 5b. Promote rule-shaped docs (`docs/<x>.md` → `rules/<x>.md`)

- Call `/create-docs rule <x>` with the doc's constraint-shaped content.
- Add correct `paths:` frontmatter — rules without `paths:` load every session, avoid unless the rule applies project-wide.
- Grep-update every reference to the old doc path across `.claude/**`.
- Delete the source doc LAST (destructive — explicit approval).

#### 5c. Generate missing rules from CLAUDE.md sections

- Call `/create-docs rule <topic>` with the section content.
- Apply scoped `paths:` matching the section's file-type scope.
- Run `docs/how-to-slim-claude-md.md` recipe to remove the duplicated section from `CLAUDE.md` with a pointer replacement.

#### 5d. Move misplaced files

- `.mmd` anywhere outside `sequences/` → `git mv` to `sequences/<name>.mmd`.
- Skill-shaped doc outside `skills/` → `git mv` to `skills/<name>/SKILL.md`.
- Agent-shaped doc outside `agents/` → `git mv` to `agents/<name>.md`.
- Grep-update every reference. Verify no stale links remain.

### 6. Deletions

Applied last, after every other repair has verified clean:

- Orphan module `CLAUDE.md` (no files in that module anymore)
- Dead rules (`paths:` matches 0 files after the user confirmed no re-scope)
- Source docs after successful rule promotion

Each deletion requires explicit approval. Even in `auto` mode, always prompt.

## Verification After Each Write

- Re-read the file; confirm it parses (valid YAML frontmatter, valid markdown, valid Mermaid if `.mmd`).
- If the final verify phase (`/validate-claude-docs` no-fix) reports `[ERR]` on a file we wrote this session, revert the change and flag in the report.

## Rollback

If the user says "revert" mid-session:

- Use git to undo writes — `git checkout -- <file>` for modifications, `git mv` reversed for renames.
- Do NOT try to reconstruct from memory; the filesystem is the source of truth.
- Report what was rolled back in the final summary.

## Related

- SKILL.md: `skills/update-docs/SKILL.md`
- Drift kinds catalog: `docs/reference-drift-catalog.md`
- CLAUDE.md slim recipe: `docs/how-to-slim-claude-md.md`
