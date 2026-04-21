---
name: create-docs
scope: api
description: "Create or scaffold .claude documentation files (rules, skills, agents, settings, CLAUDE.md)"
user-invocable: true
argument-hint: "<type> [name]"
---

# Create .claude Documentation

> **Flow:** read `sequences/create-docs.mmd` — the sequence diagram is the source of truth for execution order
> Reference guide: read `docs/how-to-create-docs.md`
> Style rules: read `rules/markdown-style.md`

Generate .claude documentation files following the official structure, adapted to the project's actual technology stack.

## Usage

`/create-docs <type> [name] [description]`

**Types:**

| Type | Creates | Example |
| ---- | ------- | ------- |
| `rule` | `rules/<name>.md` | `/create-docs rule api-design` |
| `skill` | `skills/<name>/SKILL.md` | `/create-docs skill deploy` |
| `agent` | `agents/<name>.md` | `/create-docs agent code-reviewer` |
| `settings` | `.claude/settings.json` | `/create-docs settings` |
| `claude-md` | `CLAUDE.md` | `/create-docs claude-md` |
| `doc` | `docs/<prefix>-<name>.md` | `/create-docs doc how-to api-versioning` |

**Doc sub-types** (for `/create-docs doc <sub-type> <name>`): `tutorial`, `how-to`, `checklist`, `research`, `reference`, `mapping`. The sub-type becomes the filename prefix and picks the template + size tier. See `rules/docs-folder-structure.md` for conventions.

If no type is given, ask the user what they want to create.

## Reference

Detailed instructions for each phase in the sequence diagram.

### Detect project stack

Technology markers:

| Marker file | Stack |
| ---- | ------- |
| `*.sln`, `*.vcxproj`, `.clang-format` | C++ / MSVC |
| `go.mod` | Go |
| `Cargo.toml` | Rust |
| `pyproject.toml`, `requirements.txt`, `setup.py` | Python |
| `package.json` | Node.js / TypeScript |
| `pom.xml`, `build.gradle` | Java / Kotlin |
| `*.csproj`, `*.fsproj` | C# / .NET |
| `Gemfile` | Ruby |
| `pubspec.yaml` | Dart / Flutter |
| `Makefile` (alone) | C / generic |

Also detect:

- Formatter configs: `.clang-format`, `.prettierrc`, `pyproject.toml [tool.ruff]`, `rustfmt.toml`, `.editorconfig`
- Linter configs: `.clang-tidy`, `.eslintrc*`, `ruff.toml`, `clippy.toml`, `.golangci.yml`
- Test configs: `jest.config.*`, `pytest.ini`, `*_test.go` patterns
- CI configs: `.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`

### Gather context

Per-type requirements:

- **Rule with `paths:`** — verify glob patterns match actual project files using Glob
- **Skill** — ask what the skill should do if `$ARGUMENTS` doesn't include a description
- **Agent** — ask which tools it needs and what model to use
- **Settings** — check if `.claude/settings.json` already exists and merge, don't overwrite
- **CLAUDE.md** — read project root to detect build system, test framework, directory structure; pre-fill with real values instead of placeholders

### Generate file

Constraints:

- **Frontmatter:** use kebab-case for all field names (`argument-hint`, not `argument_hint`)
- **Rules:** include `paths:` frontmatter with globs matching the detected stack (e.g. `**/*.py` for Python, `**/*.go` for Go)
- **Skills:** use `disable-model-invocation: true` for user-only workflows (deploy, release, etc.). **If the skill body uses `$ARGUMENTS`, the frontmatter MUST include `argument-hint: "<description>"`** — otherwise users have no signal what to pass.
- **Agents:** always specify `tools:` to restrict access; use `tools: Read, Grep, Glob` for read-only agents
- **Settings:** hooks use `PostToolUse` format (not `postToolCall`); permissions should include stack-specific build/test commands
- **CLAUDE.md:** fill in real values from detected stack — never leave `{{placeholders}}`; include actual directory tree from `ls`
- **Content:** be specific and actionable, not generic placeholders

### Verify

Checks per type:

- **All:** file created at correct location, valid YAML frontmatter
- **Rule with `paths:`** — at least one file matches the glob
- **Skill** — supporting files referenced in SKILL.md exist
- **CLAUDE.md** — no `{{}}` placeholders remain

### Canonical `.claude/` layout

When scaffolding, place new files only in these officially-supported subdirs. `validate-claude-docs` will flag anything else as non-canonical.

| Subdir | Contents |
| ---- | ---- |
| `rules/` | Rule `.md` files (with `paths:` frontmatter for conditional loading) |
| `skills/<name>/` | Skill dir — contains `SKILL.md` + bundled files (`templates/`, `examples/`, scripts) |
| `agents/` | Agent `.md` files with `description`, `model`, `tools` frontmatter |
| `sequences/` | `.mmd` diagrams — source of truth for skill flow |
| `docs/` | Reference prose — checklists, how-tos, tutorials, research reports |
| `commands/` | Legacy slash-command `.md` files — prefer `skills/` for new work |
| `hooks/` | Shell scripts invoked from `settings.json` |
| `output-styles/` | Output style `.md` files |
| `plugins/` | Plugin definitions |
| `memory/`, `agent-memory/` | Auto-populated — do not hand-scaffold |

Non-canonical names like `checklists/`, `examples/`, `templates/`, `mappings/` at the top level are NOT supported. Move to the appropriate canonical location:

- Prose checklists → `docs/checklist-<name>.md`
- Mapping docs → `docs/mapping-<name>.md`
- Skill-internal bundles → `skills/<name>/templates/` or `skills/<name>/examples/`

## Output

```text
[CREATED] rules/api-design.md — conditional rule for src/api/**/*.py
[STACK]   Detected: Python 3.12 + FastAPI + pytest
```

If the file already exists, ask before overwriting.
